import os
import argparse
import sys

# Production MongoDB connection string
PROD_MONGODB_URI = "mongodb+srv://admin:admin@cluster0.8czn7.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"

class Config:
    """Configuration management for development and production environments."""
    
    def __init__(self, env='dev'):
        """Initialize configuration based on environment."""
        if env == 'dev':
            self.host = "localhost"
            self.port = 27017
            self.username = "admin"
            self.password = "admin"
            self.db_name = "admin"
            self.mongodb_uri = f"mongodb://{self.username}:{self.password}@{self.host}:{self.port}/"
        elif env == 'prod':
            self.host = "cluster0.8czn7.mongodb.net"
            self.port = 27017
            self.username = "admin"
            self.password = "admin"
            self.db_name = "admin"
            self.mongodb_uri = f"mongodb+srv://{self.username}:{self.password}@{self.host}/?retryWrites=true&w=majority&appName=Cluster0"

        else:
            raise ValueError(f"Invalid environment: {env}. Use 'dev' or 'prod'.")

        # OpenAI API Key (consider using environment variable)
        self.openai_api_key = os.environ.get('OPENAI_API_KEY', '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')

def parse_args(script_name=None):
    """
    Parse command-line arguments for environment configuration.
    
    Args:
        script_name (str, optional): Name of the script for help message
    
    Returns:
        Config: Configured environment settings
    """
    parser = argparse.ArgumentParser(
        description=f'Run {script_name or "script"} in dev or prod environment',
        epilog='Use --dev or --prod to specify the environment'
    )
    
    # Mutually exclusive group ensures only one can be selected
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--dev', action='store_true', help='Run in development environment')
    group.add_argument('--prod', action='store_true', help='Run in production environment')
    
    args = parser.parse_args()
    
    # Determine environment
    if args.prod:
        return Config('prod')
    else:
        return Config('dev')  # Default to dev if no flag is provided

# If this script is run directly, show configuration details
if __name__ == "__main__":
    config = parse_args(sys.argv[0])
    print(f"Environment: {'Production' if config.mongodb_uri == PROD_MONGODB_URI else 'Development'}")
    print(f"Host: {config.host}")
    print(f"Port: {config.port}")
    print(f"Database: {config.db_name}")
