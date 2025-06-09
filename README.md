# Include shared pipelines for secret detection and common utilities
include:
  - project: ecs-catalog/pipelines/general
    ref: secret-detection_3.3
    file: /secret-detection/pipeline.yml
  - project: ecs-catalog/pipelines/general
    ref: shared_5.3
    file: /.shared/pipeline.yml

# CI variables
variables:
  CI_PROJECT_EMAIL: "${CI_ECS_GITLAB_ACCOUNT}@boeing.com"
  CLUSTER_NAME: your-eks-cluster-name  # Replace with your actual EKS cluster name
  CHART_NAME: your-application-chart   # Replace with your Helm chart name
  NODE_IMAGE: 'registry.web.boeing.com/container/boeing-images/stack/ubi8-node:8.9-1028-18.14.2'
  IMAGE_TAG: "${CI_COMMIT_REF_NAME}-${CI_PIPELINE_ID}-${CI_COMMIT_SHORT_SHA}"
  FQ_IMAGE_NAME: "${CI_REGISTRY_IMAGE}:${CI_PIPELINE_ID}"
  RULES_CHANGES_PATH: '**/*'
  AWS_REGION: us-gov-west-1  # Adjust to your AWS region
  ENTERPRISE_DOCKER_REGISTRY: registry.web.boeing.com  # Your Docker registry

# Stages
stages:
  - checkout
  - secret_detection
  - build
  - package
  - deploy
  - test
  - destroy

# Default configuration for all jobs
default:
  tags:
    - aws-155120177767  # Replace with your AWS runner tags
    - docker
    - us-gov-west-1
  image:
    name: $ENTERPRISE_DOCKER_REGISTRY/ecs-catalog/docker-images/terraform-cloud-cli/v1.8/aws-v2:1

# Base Rules
.base-rules:
  variables:
    CF_ORG: TasOrgName

# Reusable script for installing Helm
.install_helm:
  script:
    - curl -LO https://sres.web.boeing.com/artifactory/osstools/helmclient/3.4.1/helm-v3.4.1-linux-amd64.tar.gz -u "$CI_ECS_SRES_ACCOUNT:$CI_ECS_SRES_TOKEN" --insecure
    - tar -xf helm-v3.4.1-linux-amd64.tar.gz
    - mv linux-amd64/helm /usr/local/bin/helm

# Reusable script for updating EKS configuration
.update_eks_config:
  script:
    - aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    - kubectl delete secret docker-registry regcred --ignore-not-found
    - kubectl create secret docker-registry regcred --docker-server=$ENTERPRISE_DOCKER_REGISTRY --docker-username=$CI_ECS_GITLAB_ACCOUNT --docker-password=$CI_ECS_GITLAB_TOKEN --docker-email=$CI_PROJECT_EMAIL

# Build stage - compile and test the application
build:
  stage: build
  image: $NODE_IMAGE
  before_script:
    - npm config set registry=https://sres.web.boeing.com/artifactory/api/npm/npm-releases
    - npm config set //sres.web.boeing.com/:_auth=$(echo -n ${ARTIFACTORY_USERNAME}:${ARTIFACTORY_API_TOKEN} | base64 -w 0)
    - npm install
  script:
    - echo "Build and Test"
    - npm run build
    # Uncomment the line below for running tests
    # - npm run test -- --run --testTimeout=30000 --hookTimeout=30000
  except:
    - tags
    - schedules
  cache:
    key: $CI_COMMIT_REF_NAME
    paths:
      - node_modules/
  artifacts:
    name: '${CI_PROJECT_PATH_SLUG}-${CI_COMMIT_REF_SLUG}'
    when: always
    expire_in: 1 week
    paths:
      - ./*.js
      - ./package*.json
      - dist/
      - node_modules/
      - charts/  # Include Helm charts if they exist

# Package stage - build Docker image
package:
  stage: package
  only:
    - dev-deploy
    - test
    - main
  image: $ENTERPRISE_DOCKER_REGISTRY/ecs-catalog/docker-images/terraform-cloud-cli/v1.8/aws-v2:1
  variables:
    STORAGE_DRIVER: vfs
    BUILDAH_FORMAT: docker
    BUILDAH_ISOLATION: chroot
  script:
    - echo "Building Docker image for EKS deployment"
    - chmod +x pipeline/package.sh
    - ./pipeline/package.sh
    # Push image to registry
    - docker tag $FQ_IMAGE_NAME $ENTERPRISE_DOCKER_REGISTRY/$CI_PROJECT_PATH:$IMAGE_TAG
    - docker push $ENTERPRISE_DOCKER_REGISTRY/$CI_PROJECT_PATH:$IMAGE_TAG
  except:
    - schedules
  needs:
    - build

# Deploy Template for EKS
.deploy-template:
  stage: deploy
  needs:
    - build
    - package
  before_script:
    - !reference [.install_helm, script]
    - !reference [.update_eks_config, script]
  script:
    - echo "Deploying to EKS cluster $CLUSTER_NAME"
    # Update image tag in values or use --set flag
    - |
      if [ -f charts/values-${CI_ENVIRONMENT_NAME}.yaml ]; then
        VALUES_FILE="charts/values-${CI_ENVIRONMENT_NAME}.yaml"
      else
        VALUES_FILE="charts/values.yaml"
      fi
    - |
      helm upgrade --install $CHART_NAME-${CI_ENVIRONMENT_NAME} ./charts \
        --namespace ${CI_ENVIRONMENT_NAME} \
        --create-namespace \
        --values $VALUES_FILE \
        --set image.repository=$ENTERPRISE_DOCKER_REGISTRY/$CI_PROJECT_PATH \
        --set image.tag=$IMAGE_TAG \
        --wait \
        --timeout=300s

# Deploy Dev
deploy-dev:
  extends: .deploy-template
  environment: 
    name: dev
    url: https://$CHART_NAME-dev.$AWS_REGION.elb.amazonaws.com  # Adjust URL pattern as needed
  variables:
    CLUSTER_NAME: your-dev-eks-cluster  # Replace with dev cluster name
  only:
    - dev-deploy

# Deploy Test
deploy-test:
  extends: .deploy-template
  environment: 
    name: test
    url: https://$CHART_NAME-test.$AWS_REGION.elb.amazonaws.com  # Adjust URL pattern as needed
  variables:
    CLUSTER_NAME: your-test-eks-cluster  # Replace with test cluster name
  only:
    - test
  when: manual

# Deploy Prod
deploy-prod:
  extends: .deploy-template
  environment: 
    name: prod
    url: https://$CHART_NAME-prod.$AWS_REGION.elb.amazonaws.com  # Adjust URL pattern as needed
  variables:
    CLUSTER_NAME: your-prod-eks-cluster  # Replace with prod cluster name
  only:
    - main
  when: manual

# Verify application deployment
verify_application:
  stage: test
  needs:
    - deploy-dev
  script:
    - !reference [.update_eks_config, script]
    - |
      # Wait for ingress to be ready
      echo "Waiting for ingress to be populated..."
      address=$(kubectl get ingress --namespace dev --no-headers | awk '{print $4}')
      while [ -z "$address" ] || [ "$address" == "<none>" ]; do
        echo "Waiting for ingress address to be populated..."
        sleep 10
        address=$(kubectl get ingress --namespace dev --no-headers | awk '{print $4}')
      done
      echo "Ingress address: $address"
      
      # Test the application endpoint
      echo "Testing application endpoint..."
      response=$(curl --connect-timeout 10 --max-time 10 --retry 10 --retry-delay 10 --retry-max-time 30 --write-out "HTTPSTATUS:%{http_code}" --silent --output /dev/null http://$address)
      http_code=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
      
      if [ "$http_code" -eq 200 ]; then
        echo "Application is responding correctly (HTTP $http_code)"
      else
        echo "Application test failed (HTTP $http_code)"
        exit 1
      fi
  only:
    - dev-deploy
  allow_failure: true

# Manual cleanup job
uninstall_chart:
  stage: destroy
  when: manual
  script:
    - !reference [.install_helm, script]
    - !reference [.update_eks_config, script]
    - |
      echo "Listing current Helm releases..."
      helm list --all-namespaces
      
      # Uninstall from all environments
      for env in dev test prod; do
        echo "Checking for $CHART_NAME-$env..."
        if helm list --namespace $env | grep -q "$CHART_NAME-$env"; then
          echo "Uninstalling $CHART_NAME-$env from namespace $env..."
          helm uninstall $CHART_NAME-$env --namespace $env
        else
          echo "Chart $CHART_NAME-$env not found in namespace $env"
        fi
      done
  allow_failure: true
