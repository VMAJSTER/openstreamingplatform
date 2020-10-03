from classes.settings import settings

from app import ejabberd

def getChannelCounts(channelLoc):
    sysSettings = settings.query.first()

    roomOccupantsJSON = ejabberd.get_room_occupants_number(channelLoc, "conference." + sysSettings.siteAddress)
    currentViewers = roomOccupantsJSON['occupants']

    return currentViewers
