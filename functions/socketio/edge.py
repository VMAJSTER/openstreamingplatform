import requests
import xmltodict

from flask import abort
from flask_security import current_user
from flask_socketio import emit

from classes.shared import db, socketio
from classes import settings

from functions import system


@socketio.on('checkEdge')
def checkEdgeNode(message):
    if current_user.has_role('Admin'):
        edgeID = int(message['edgeID'])
        edgeNodeQuery = settings.edgeStreamer.query.filter_by(id=edgeID).first()
        if edgeNodeQuery is not None:
            try:
                edgeXML = requests.get("http://" + edgeNodeQuery.address + ":9000/stat").text
                edgeDict = xmltodict.parse(edgeXML)
                if "nginx_rtmp_version" in edgeDict['rtmp']:
                    edgeNodeQuery.status = 1
                    emit('edgeNodeCheckResults', {'edgeID': str(edgeNodeQuery.id), 'status': str(1)}, broadcast=False)
                    try:
                        db.session.commit()
                    except:
                        db.session.rollback()
                    return 'OK'
            except:
                edgeNodeQuery.status = 0
                emit('edgeNodeCheckResults', {'edgeID': str(edgeNodeQuery.id), 'status': str(0)}, broadcast=False)
                try:
                    db.session.commit()
                except:
                    db.session.rollback()
                db.session.close()
                return 'OK'
        try:
            db.session.commit()
        except:
            db.session.rollback()
        db.session.close()
        return abort(500)
    try:
        db.session.commit()
    except:
        db.session.rollback()
    db.session.close()
    return abort(401)

@socketio.on('toggleOSPEdge')
def toggleEdgeNode(message):
    if current_user.has_role('Admin'):
        edgeID = int(message['edgeID'])
        edgeNodeQuery = settings.edgeStreamer.query.filter_by(id=edgeID).first()
        if edgeNodeQuery is not None:
            edgeNodeQuery.active = not edgeNodeQuery.active
            try:
                db.session.commit()
            except:
                db.session.rollback()
            system.rebuildOSPEdgeConf()
            db.session.close()
            return 'OK'
        else:
            try:
                db.session.commit()
            except:
                db.session.rollback()
            db.session.close()
            return abort(500)
    else:
        try:
            db.session.commit()
        except:
            db.session.rollback()
        db.session.close()
        return abort(401)

@socketio.on('deleteOSPEdge')
def deleteEdgeNode(message):
    if current_user.has_role('Admin'):
        edgeID = int(message['edgeID'])
        edgeNodeQuery = settings.edgeStreamer.query.filter_by(id=edgeID).first()
        if edgeNodeQuery is not None:
            db.session.delete(edgeNodeQuery)
            try:
                db.session.commit()
            except:
                db.session.rollback()
            system.rebuildOSPEdgeConf()
            db.session.close()
            return 'OK'
        else:
            try:
                db.session.commit()
            except:
                db.session.rollback()
            db.session.close()
            return abort(500)
    else:
        try:
            db.session.commit()
        except:
            db.session.rollback()
        db.session.close()
        return abort(401)
