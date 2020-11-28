version = "0.7.9"
appDBVersion = 0.70

videoRoot = "/var/www/"

# In-Memory Cache of Topic Names
topicCache = {}

# Create In-Memory Invite Cache to Prevent High CPU Usage for Polling Channel Permissions during Streams
inviteCache = {}

# Build Channel Restream Subprocess Dictionary
restreamSubprocesses = {}

# Build Edge Restream Subprocess Dictionary
activeEdgeNodes = []
edgeRestreamSubprocesses = {}

# ejabberd Server Configuration
ejabberdServer = "127.0.0.1"

recaptchaEnabled = False

