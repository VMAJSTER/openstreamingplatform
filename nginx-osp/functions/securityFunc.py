from flask_security import current_user
import datetime

from classes.shared import db
from classes import Channel
from classes import Sec
from classes import invites

from globals import globalvars

def check_isUserValidRTMPViewer(userID,channelID):
    userQuery = Sec.User.query.filter_by(id=userID).with_entities(Sec.User.id).first()
    if userQuery is not None:
        channelQuery = Channel.Channel.query.filter_by(id=channelID).with_entities(Channel.Channel.owningUser).first()
        if channelQuery is not None:
            if channelQuery.owningUser is userQuery.id:
                #db.session.close()
                return True
            else:
                inviteQuery = invites.invitedViewer.query.filter_by(userID=userQuery.id, channelID=channelID).all()
                for invite in inviteQuery:
                    if invite.isValid():
                        db.session.close()
                        return True
                    else:
                        db.session.delete(invite)
                        db.session.commit()
                        db.session.close()
    return False