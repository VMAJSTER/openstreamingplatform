import hashlib

from flask import Blueprint, request, url_for, render_template, redirect, current_app, send_from_directory, abort, flash
from flask_security import current_user, login_required
from sqlalchemy.sql.expression import func

from classes.shared import db
from classes import Sec

from classes import Channel
from classes import settings

from functions import securityFunc

root_bp = Blueprint('root', __name__)

@root_bp.route('/robots.txt')
def static_from_root():
    return send_from_directory(current_app.static_folder, request.path[1:])

@root_bp.route('/auth', methods=["POST","GET"])
def auth_check():
    sysSettings = settings.settings.query.with_entities(settings.settings.protectionEnabled).first()
    if sysSettings.protectionEnabled is False:
        return 'OK'

    channelID = ""
    if 'X-Channel-ID' in request.headers:
        channelID = request.headers['X-Channel-ID']
        channelQuery = Channel.Channel.query.filter_by(channelLoc=channelID).with_entities(Channel.Channel.id, Channel.Channel.protected).first()
        if channelQuery is not None:
            if channelQuery.protected:
                if securityFunc.check_isValidChannelViewer(channelQuery.id):
                    db.session.close()
                    return 'OK'
                else:
                    db.session.close()
                    return abort(401)
            else:
                return 'OK'

    db.session.close()
    abort(400)

@root_bp.route('/playbackAuth', methods=['POST'])
def playback_auth_handler():
    stream = request.form['name']
    clientIP = request.form['addr']

    if clientIP == "127.0.0.1" or clientIP == "localhost":
        return 'OK'
    else:
        streamQuery = Channel.Channel.query.filter_by(channelLoc=stream).first()
        if streamQuery is not None:

            if streamQuery.protected is False:
                db.session.close()
                return 'OK'
            else:
                username = request.form['username']
                secureHash = request.form['hash']

                if streamQuery is not None:
                    requestedUser = Sec.User.query.filter_by(username=username).first()
                    if requestedUser is not None:
                        isValid = False
                        validHash = None
                        if requestedUser.authType == 0:
                            validHash = hashlib.sha256((requestedUser.username + streamQuery.channelLoc + requestedUser.password).encode('utf-8')).hexdigest()
                        else:
                            validHash = hashlib.sha256((requestedUser.username + streamQuery.channelLoc + requestedUser.oAuthID).encode('utf-8')).hexdigest()
                        if secureHash == validHash:
                            isValid = True
                        if isValid is True:
                            if streamQuery.owningUser == requestedUser.id:
                                db.session.close()
                                return 'OK'
                            else:
                                if securityFunc.check_isUserValidRTMPViewer(requestedUser.id,streamQuery.id):
                                    db.session.close()
                                    return 'OK'
    db.session.close()
    return abort(400)
