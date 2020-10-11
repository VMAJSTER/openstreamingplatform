# -*- coding: UTF-8 -*-
from gevent import monkey
monkey.patch_all(thread=True)

# Import Standary Python Libraries
import socket
import os
import subprocess
import time
import sys
import hashlib
import logging
import datetime
import json
import uuid

# Import 3rd Party Libraries
from flask import Flask, redirect, request, abort, flash
from flask_security import Security, SQLAlchemyUserDatastore
from flask_cors import CORS
from werkzeug.middleware.proxy_fix import ProxyFix

# Import Paths
cwp = sys.path[0]
sys.path.append(cwp)
sys.path.append('./classes')

#----------------------------------------------------------------------------#
# Configuration Imports
#----------------------------------------------------------------------------#
from conf import config

#----------------------------------------------------------------------------#
# Global Vars Imports
#----------------------------------------------------------------------------#
from globals import globalvars

#----------------------------------------------------------------------------#
# App Configuration Setup
#----------------------------------------------------------------------------#
coreNginxRTMPAddress = "127.0.0.1"

app = Flask(__name__)

# Flask App Environment Setup
app.debug = config.debugMode
app.wsgi_app = ProxyFix(app.wsgi_app)
app.jinja_env.cache = {}
app.config['WEB_ROOT'] = globalvars.videoRoot
app.config['SQLALCHEMY_DATABASE_URI'] = config.dbLocation
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
if config.dbLocation[:6] != "sqlite":
    app.config['SQLALCHEMY_MAX_OVERFLOW'] = -1
    app.config['SQLALCHEMY_POOL_RECYCLE'] = 300
    app.config['SQLALCHEMY_POOL_TIMEOUT'] = 600
    app.config['MYSQL_DATABASE_CHARSET'] = "utf8"
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {'encoding': 'utf8', 'pool_use_lifo': 'False', 'pool_size': 10, "pool_pre_ping": True}
else:
    pass

app.config['SESSION_COOKIE_SAMESITE'] = "Lax"
app.config['SESSION_COOKIE_NAME'] = 'ospSession'
app.config['SECRET_KEY'] = config.secretKey
app.config['SECURITY_PASSWORD_HASH'] = "pbkdf2_sha512"
app.config['SECURITY_PASSWORD_SALT'] = config.passwordSalt
app.config['SECURITY_REGISTERABLE'] = False
app.config['SECURITY_RECOVERABLE'] = False
app.config['SECURITY_CHANGABLE'] = False
app.config['SECURITY_USER_IDENTITY_ATTRIBUTES'] = ['username','email']
app.config['SECURITY_FLASH_MESSAGES'] = True

logger = logging.getLogger('gunicorn.error').handlers

#----------------------------------------------------------------------------#
# Modal Imports
#----------------------------------------------------------------------------#

from classes import Stream
from classes import Channel
from classes import dbVersion
from classes import RecordedVideo
from classes import topics
from classes import settings
from classes import banList
from classes import Sec
from classes import upvotes
from classes import apikey
from classes import views
from classes import comments
from classes import invites
from classes import webhook
from classes import logs
from classes import subscriptions
from classes import notifications

#----------------------------------------------------------------------------#
# Function Imports
#----------------------------------------------------------------------------#
from functions import database
from functions import system
from functions import securityFunc
from functions import webhookFunc
from functions.ejabberdctl import ejabberdctl
#----------------------------------------------------------------------------#
# Begin App Initialization
#----------------------------------------------------------------------------#
# Begin Database Initialization
from classes.shared import db
db.init_app(app)
db.app = app

# Initialize Flask-CORS Config
cors = CORS(app, resources={r"/apiv1/*": {"origins": "*"}})

# Initialize Flask-Security
user_datastore = SQLAlchemyUserDatastore(db, Sec.User, Sec.Role)
security = Security(app, user_datastore, register_form=Sec.ExtendedRegisterForm, confirm_register_form=Sec.ExtendedConfirmRegisterForm, login_form=Sec.OSPLoginForm)

# Initialize ejabberdctl
ejabberd = None

if hasattr(config,'ejabberdServer'):
    globalvars.ejabberdServer = config.ejabberdServer

try:
    ejabberd = ejabberdctl(config.ejabberdHost, config.ejabberdAdmin, config.ejabberdPass, server=globalvars.ejabberdServer)
    print(ejabberd.status())
except Exception as e:
    print("ejabberdctl failed to load: " + str(e))

# Attempt Database Load and Validation
try:
    database.init(app, user_datastore)
except:
    print("DB Load Fail due to Upgrade or Issues")

# Initialize Flask-Mail
from classes.shared import email

email.init_app(app)
email.app = app

#----------------------------------------------------------------------------#
# Blueprint Filter Imports
#----------------------------------------------------------------------------#
from blueprints.rtmp import rtmp_bp
from blueprints.root import root_bp

# Register all Blueprints
app.register_blueprint(rtmp_bp)
app.register_blueprint(root_bp)

#----------------------------------------------------------------------------#
# Template Filter Imports
#----------------------------------------------------------------------------#
from functions import templateFilters

# Initialize Jinja2 Template Filters
templateFilters.init(app)

#----------------------------------------------------------------------------#
# Additional Handlers.
#----------------------------------------------------------------------------#
@app.teardown_appcontext
def shutdown_session(exception=None):
    db.session.remove()

#----------------------------------------------------------------------------#
# Finalize App Init
#----------------------------------------------------------------------------#
if __name__ == '__main__':
    app.run(Debug=config.debugMode)
