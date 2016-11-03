_       = require 'lodash'
async   = require 'async'
debug   = require('debug')('interval-service:message-service')

class MessageService
  constructor: ({database}) ->
    throw new error 'IntervalService requires: database' unless database?
    @collection = database.collection 'soldiers'

  subscribe: (params, callback) =>
    debug 'subscribe', JSON.stringify params
    return callback(new Error 'nodeId or sendTo not defined') unless params?.sendTo? && params?.nodeId?
    return callback(new Error 'noUnsubscribe should also set fireOnce') if params.noUnsubscribe and !params.fireOnce
    return callback(new Error 'intervalTime must be at least 1000ms') if !params.cronString && params.intervalTime < 1000
    @createRegisterJob params, callback

  unsubscribe: (params, callback) =>
    debug 'unsubscribe', JSON.stringify params
    return callback new Error 'nodeId or sendTo not defined' unless params?.sendTo? && params?.nodeId?
    @createUnregisterJob params, callback

  createRegisterJob: (data, callback) =>
    @_storeJobInMongo data, callback

  createUnregisterJob: (data, callback)=>
    @_removeJobInMongo data, callback

  _storeJobInMongo: (data, callback) =>
    ownerId = data.sendTo
    nodeId = data.transactionId ? data.nodeId # allow dynamic intervals
    return callback() if data?.fireOnce
    @collection.update {ownerId, nodeId}, {$set: {ownerId, nodeId, data}}, upsert: true, callback

module.exports = MessageService
