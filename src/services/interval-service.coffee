_           = require 'lodash'
async       = require 'async'
MeshbluHttp = require 'meshblu-http'

class IntervalService
  constructor: ({@meshbluConfig, database, @intervalServiceUri}) ->
    throw new error 'IntervalService: requires meshbluConfig' unless @meshbluConfig?
    throw new error 'IntervalService: requires database' unless database?
    throw new error 'IntervalService: requires intervalServiceUri' unless @intervalServiceUri?
    @collection = database.collection 'soldiers'

  create: (params, callback) =>
    ownerUuid  = params.uuid
    ownerToken = params.token
    nodeId     = params.nodeId

    options =
      owner: ownerUuid
      createdBy: 'interval-service'
      meshblu:
        version: '2.0.0'
        whitelists:
          configure:
            update: [{uuid: ownerUuid}]
          discover:
            view: [{uuid: ownerUuid}]
          message:
            from: [{uuid: ownerUuid}]
        forwarders:
          message:
            received: [
              {
                url: "#{@intervalServiceUri}/message"
                type: 'webhook'
                method: 'POST'
                signRequest: true
              }
            ]

    @_getMeshbluHttp({ uuid: ownerUuid, token: ownerToken })
      .register options, (error, device) =>
        return callback error if error?
        intervalUuid = device.uuid
        intervalToken = device.token
        options = {
          emitterUuid: intervalUuid
          subscriberUuid: intervalUuid
          type: 'message.received'
        }
        @_getMeshbluHttp({ uuid: intervalUuid, token: intervalToken })
          .createSubscription options, (error) =>
            return callback error if error?
            data =
              'metadata.ownerUuid': ownerUuid
              'metadata.intervalUuid': intervalUuid
              'metadata.nodeId': nodeId
              'data.uuid': intervalUuid
              'data.token': intervalToken
              'data.nodeId': nodeId
            query =
              'metadata.ownerUuid': ownerUuid
              'metadata.nodeId': nodeId
            @collection.update query, {$set: data}, {upsert: true}, (error) =>
              return callback error if error?
              callback null, device

  destroy: ({uuid, token, nodeId, intervalUuid}, callback) =>
    @_getMeshbluHttp({uuid, token}).unregister { uuid: intervalUuid }, (error) =>
      return callback error if error?
      @collection.remove {'metadata.intervalUuid': intervalUuid}, callback

  _getMeshbluHttp: ({ uuid, token }) =>
    return new MeshbluHttp _.defaults {uuid, token}, @meshbluConfig

  _createError: (code, message) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = IntervalService
