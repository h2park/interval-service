_ = require 'lodash'
MeshbluHttp = require 'meshblu-http'

class IntervalService
  constructor: ({@meshbluConfig}) ->
    throw new error 'IntervalService requires: meshbluConfig' unless @meshbluConfig?

  create: ({uuid, token}, callback) =>
    meshbluHttp = new MeshbluHttp _.extend {uuid, token}, @meshbluConfig
    options =
      configureWhitelist: [uuid]
      discoverWhitelist: [uuid]
      owner: uuid
      createdBy: 'interval-service'

    meshbluHttp.register options, (error, device) =>
      return callback error if error?
      callback null, device

  _createError: (code, message) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = IntervalService
