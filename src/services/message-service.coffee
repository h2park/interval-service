_       = require 'lodash'
async   = require 'async'
debug   = require('debug')('interval-service:message-service')

class MessageService
  constructor: ({database}) ->
    throw new error 'IntervalService requires: database' unless database?
    @collection = database.collection 'soldiers'

  subscribe: (params={}, callback) =>
    debug 'subscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    if params.noUnsubscribe and !params.fireOnce
      return callback @_userError('noUnsubscribe should also set fireOnce', 422)
    if !params.cronString and params.intervalTime < 1000
      return callback @_userError('intervalTime must be at least 1000ms', 422)
    @_storeJobInMongo params, callback

  unsubscribe: (params={}, callback) =>
    debug 'unsubscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    @_removeJobInMongo params, callback

  _storeJobInMongo: (data, callback) =>
    {
      sendTo,
      intervalTime,
      fireOnce,
      nodeId,
      transactionId,
      nonce,
      cronString,
    } = data
    query =
      'metadata.ownerUuid': sendTo
      'metadata.nodeId': nodeId
    update = {}
    update['data.nodeId'] = transactionId || nodeId
    update['data.sendTo'] = sendTo if sendTo?
    update['data.transactionId'] = transactionId if transactionId?
    update['data.fireOnce'] = fireOnce || false
    update['metadata.nonce'] = nonce if nonce?
    update['metadata.intervalTime'] = intervalTime if intervalTime?
    update['metadata.cronString'] = cronString if cronString?
    @collection.update query, {$set: update}, {upsert: true}, callback

  _removeJobInMongo: (data, callback) =>
    {
      sendTo,
      nodeId,
      transactionId,
    } = data

    query = {
      'metadata.ownerUuid': sendTo
      'metadata.nodeId'   : nodeId
    }
    @collection.remove query, callback

  _userError: (message, code) =>
    error = new Error message
    error.code = code ? 500
    return error

module.exports = MessageService
