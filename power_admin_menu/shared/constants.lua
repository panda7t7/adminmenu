PAM = PAM or {}
PAM.Version = '1.5.9-object-spawner'
PAM.Events = {
    OpenRequest = 'pam:server:openRequest', Bootstrap = 'pam:client:bootstrap',
    ActionRequest = 'pam:server:action', ActionResult = 'pam:client:actionResult',
    FreezeTarget = 'pam:client:freeze', HealTarget = 'pam:client:heal',
    TeleportTarget = 'pam:client:teleport', BringTarget = 'pam:client:bring',
    SetWeather = 'pam:client:setWeather', SetTime = 'pam:client:setTime',
    SpectateStart = 'pam:client:spectateStart', SpectateStop = 'pam:client:spectateStop'
}
PAM.Permissions = {
    'dashboard.view','entities.delete','entities.spawn','entities.manage','players.view','players.teleport','players.bring','players.freeze','players.heal','players.kick','players.ban',
    'world.view','world.weather','world.time','vehicles.view','vehicles.spawn','vehicles.give','staff.view','audit.view','resources.view',
    'players.dossier','players.identifiers','players.inventory','players.money.view','players.money.modify',
    'items.view','items.give','items.create','jobs.view','jobs.create',
    'players.notes.view','players.notes.add','players.history','players.spectate','players.warn','players.unban'
}
