_ = require 'lodash'
async = require 'async'
mongojs = require 'mongojs'
MeshbluHttp = require 'meshblu-http'

class IntervalService
  constructor: ({@meshbluConfig, @mongodbUri, @intervalServiceUri}) ->
    throw new error 'IntervalService requires: meshbluConfig' unless @meshbluConfig?
    throw new error 'IntervalService requires: mongodbUri' unless @mongodbUri?
    @db = mongojs @mongodbUri, ['intervals']
    @datastore = @db.intervals

  create: ({uuid, token, nodeId}, callback) =>
    meshbluHttp = new MeshbluHttp _.extend {uuid, token}, @meshbluConfig
    options =
      owner: uuid
      createdBy: 'interval-service'
      meshblu:
        version: '2.0.0'
        whitelists:
          configure:
            update: [{uuid}]
          discover:
            view: [{uuid}]
          message:
            from: [{uuid}]
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

    meshbluHttp.register options, (error, device) =>
      return callback error if error?

      options =
        emitterUuid: device.uuid
        subscriberUuid: device.uuid
        type: 'message.received'

      deviceMeshbluHttp = new MeshbluHttp _.defaults {uuid: device.uuid, token: device.token}, @meshbluConfig
      deviceMeshbluHttp.createSubscription options, (error) =>
        return callback error if error?
        data =
          id: device.uuid
          ownerId: uuid
          nodeId: nodeId
          token: device.token

        @datastore.insert data, (error) =>
          return callback error if error?
          callback null, device

  destroy: ({uuid, token, nodeId, id}, callback) =>
    meshbluHttp = new MeshbluHttp _.extend {uuid, token}, @meshbluConfig
    options =
      owner: uuid
      createdBy: 'interval-service'

    meshbluHttp.unregister uuid: id, (error) =>
      return callback error if error?
      @datastore.remove {id}, callback

  _createError: (code, message) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = IntervalService
