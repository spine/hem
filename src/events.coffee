# ------ Setup shareable events emitter

events = new require('events')
module.exports = new events.EventEmitter()
