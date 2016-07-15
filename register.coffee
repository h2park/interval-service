_ = require 'lodash'
async = require 'async'
kue = require 'kue'
mongojs = require 'mongojs'
Redis   = require 'ioredis'

queue = kue.createQueue
  redis:
    createClientFactory: =>
      new Redis process.env.REDIS_URI, dropBufferSupport: true

client = new Redis process.env.REDIS_URI, dropBufferSupport: true
client.on 'ready', =>
  client.flushall =>
    database = mongojs process.env.MONGODB_URI, ['intervals']
    datastore = database.intervals

    register = (record, callback) =>
      queue.create('register', record.data).
        removeOnComplete(true).
        save (error) =>
          callback error

    datastore.find {}, (error, records) =>
      async.eachSeries records, register, (error) =>
        console.log {error}
        process.exit 0
