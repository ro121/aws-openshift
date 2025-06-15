import requests
from typing import Optional, Tuple
from .models import AuthTypeEnum
from .exceptions import AuthSSOError
from .utility import ResponseUtils
from .signin_strategy import SignOnStrategy
from selenium import webdriver
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.firefox.options import Options

class AutoSignOnAuth(SignOnStrategy):
    
    def __init__(self, app_url: str, post_redirect_url: str):
        super().__init__(app_url, post_redirect_url)
    
    @property
    def name(self) -> AuthTypeEnum:
        return AuthTypeEnum.AUTO_SIGN_ON
    
    def authenticate(self) -> Tuple[requests.Session, Optional[str]]:
        # Since geckodriver is now in PATH, you can use it directly
        firefox_options = Options()
        # firefox_options.add_argument('--headless')  # Uncomment for headless mode
        
        # Create Firefox driver (geckodriver will be found in PATH)
        driver = webdriver.Firefox(options=firefox_options)
        
        try:
            fragment, gas_server = self._fetch_redirect_fragment()
            query_params = ResponseUtils.get_required_query_params(fragment)
            url = (
                f"https://{gas_server}/GAS/autologin?"
                f"PingFedDropOff=true&instanceId={query_params.instance_id}&gasWebClient=true"
            )
            
            # Use Selenium to navigate to the URL
            driver.get(url)
            
            # Add your automation logic here
            # For example, wait for page load, interact with elements, etc.
            
            # Get cookies from Selenium driver
            selenium_cookies = driver.get_cookies()
            
            # Create requests session and transfer cookies
            session = requests.Session()
            for cookie in selenium_cookies:
                session.cookies.set(cookie['name'], cookie['value'])
            
            response = ResponseUtils.post_response(session, url, {})
            reference_id = response.json().get("referenceId")
            
            if not reference_id:
                raise AuthSSOError(f"{self.name}: No referenceId in auto sign-on response.")
            
            ResponseUtils.set_wso2_headers(session, reference_id, query_params)
            return session, None
            
        finally:
            # Always close the driver
            driver.quit()

# Alternative Method 2: Add geckodriver to PATH environment variable
# Then you can use: driver = webdriver.Firefox()

# Alternative Method 3: Use WebDriverManager (recommended)
# First install: pip install webdriver-manager
# Then use:
"""
from webdriver_manager.firefox import GeckoDriverManager

class AutoSignOnAuth(SignOnStrategy):
    # ... other methods ...
    
    def authenticate(self) -> Tuple[requests.Session, Optional[str]]:
        service = Service(GeckoDriverManager().install())
        driver = webdriver.Firefox(service=service)
        # ... rest of the code ...
"""
