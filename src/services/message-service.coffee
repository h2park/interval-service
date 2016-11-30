_        = require 'lodash'
async    = require 'async'
moment   = require 'moment'
uuid     = require 'uuid'
debug    = require('debug')('interval-service:message-service')
overview = require('debug')('interval-service:message-service:overview')

class MessageService
  constructor: ({database}) ->
    throw new error 'MessageService: requires database' unless database?
    @collection = database.collection 'soldiers'

  subscribe: (params={}, callback) =>
    debug 'subscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    if params.noUnsubscribe and !params.fireOnce
      return callback @_userError('noUnsubscribe should also set fireOnce', 422)
    if !params.cronString and params.intervalTime < 1000
      return callback @_userError('intervalTime must be at least 1000ms', 422)
    @_upsertInstance params, callback

  unsubscribe: (params={}, callback) =>
    debug 'unsubscribe', JSON.stringify params
    unless params.sendTo? and params.nodeId?
      return callback @_userError('nodeId or sendTo not defined', 422)
    @_removeInstances params, callback

  _upsertInstance: (data, callback) =>
    @_removeInstances data, (error) =>
      return callback error if error?
      @_getCredentials data, (error, credentials) =>
        return callback error if error?
        update  = { $set: @_cloneCredentialsRecord(data, credentials) }
        query   = @_getInstancesQuery(data)
        options = { multi:true, upsert:true }
        # Upsert to reduce the chance of race condition
        @collection.update query, update, options, (error, result) =>
          return callback error if error?
          callback null

  _getCredentials: ({ sendTo, nodeId }, callback) =>
    query =
      'metadata.ownerUuid'      : sendTo
      'metadata.nodeId'         : nodeId
      'metadata.credentialsOnly': true
    @collection.findOne query, {_id: false}, (error, credentials) =>
      return callback error if error?
      return callback @_userError("Missing credentials", 412) unless credentials?
      callback null, credentials

  _cloneCredentialsRecord: (data, credentials) =>
    {
      sendTo,
      intervalTime,
      fireOnce,
      nodeId,
      transactionId,
      nonce,
      cronString,
    } = data
    fireOnce ?= false
    defaults = {
      metadata: {
        transactionId,
        nonce,
        intervalTime,
        cronString,
        fireOnce,
        processNow: true,
        lastRunAt: moment().unix(),
        credentialsOnly: false
      },
      data: {
        nodeId,
        sendTo,
        transactionId,
        fireOnce
      }
    }
    return JSON.parse JSON.stringify _.defaultsDeep(defaults, credentials)

  _removeInstances: (data, callback) =>
    @collection.remove @_getInstancesQuery(data), {multi:true}, callback

  _getInstancesQuery: ({ sendTo, nodeId, transactionId }) =>
    query = {}
    query['metadata.ownerUuid'] = sendTo
    query['metadata.nodeId'] = nodeId
    query['metadata.transactionId'] = transactionId if transactionId?
    query['metadata.credentialsOnly'] = false
    return query

  _userError: (message, code) =>
    error = new Error message
    error.code = code ? 500
    return error

module.exports = MessageService
