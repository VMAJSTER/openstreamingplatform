# Set Database Location and Type
# For MySQL Connections add ?charset=utf8mb4 for full Unicode Support
dbLocation = 'sqlite:///db/database.db'

# Redis Configuration
redisHost="localhost" # Default localhost
redisPort=6379 # Default 6379
redisPassword=None # Default None

# Flask Secret Key
secretKey = "Super-Sekrit"

# Password Salt Value
passwordSalt = "los-salt"

# Allow Users to Register with the OSP Server
allowRegistration = True

# Require Users to Confirm their Email Addresses
requireEmailRegistration = True

# Enables Debug Mode
debugMode = False

# EJabberD Configuration
ejabberdAdmin = "admin"
ejabberdPass = "CHANGE_EJABBERD_PASS"
ejabberdHost = "localhost"
#ejabberdServer ="127.0.0.1"