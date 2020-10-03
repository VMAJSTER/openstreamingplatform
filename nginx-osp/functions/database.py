import os

from flask import flash

from globals import globalvars

from classes.shared import db
from classes import settings
from classes import topics


def init(app, user_datastore):

    topicList = [("Other","None")]
    for topic in topicList:
        existingTopic = topics.topics.query.filter_by(name=topic[0]).first()
        if existingTopic is None:
            newTopic = topics.topics(topic[0], topic[1])
            db.session.add(newTopic)
    db.session.commit()

    # Note: for a freshly installed system, sysSettings is None!
    sysSettings = settings.settings.query.first()

    if sysSettings is not None:

        # Create the stream-thumb directory if it does not exist
        if not os.path.isdir(app.config['WEB_ROOT'] + "stream-thumb"):
            try:
                os.mkdir(app.config['WEB_ROOT'] + "stream-thumb")
            except OSError:
                flash("Unable to create <web-root>/stream-thumb", "error")

        sysSettings = settings.settings.query.first()

        app.config['SERVER_NAME'] = None
        app.config['SECURITY_EMAIL_SENDER'] = sysSettings.smtpSendAs
        app.config['MAIL_DEFAULT_SENDER'] = sysSettings.smtpSendAs
        app.config['MAIL_SERVER'] = sysSettings.smtpAddress
        app.config['MAIL_PORT'] = sysSettings.smtpPort
        app.config['MAIL_USE_SSL'] = sysSettings.smtpSSL
        app.config['MAIL_USE_TLS'] = sysSettings.smtpTLS
        app.config['MAIL_USERNAME'] = sysSettings.smtpUsername
        app.config['MAIL_PASSWORD'] = sysSettings.smtpPassword

        # Initialize the Topic Cache
        topicQuery = topics.topics.query.all()
        for topic in topicQuery:
            globalvars.topicCache[topic.id] = topic.name