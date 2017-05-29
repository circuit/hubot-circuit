{Robot, Adapter, TextMessage, User} = require 'hubot'

fs = require 'fs'
http = require 'http'
https = require 'https'
express = require 'express'
bodyParser = require 'body-parser'
request = require 'request'

class CircuitBot extends Adapter

  # RestAPI Endpoints
  URL =
    GET_TOKEN: '/oauth/token'
    WEBHOOK: '/webhooks'
    CREATE_DIRECT_CONVERSATION: '/conversations/direct'
    CREATE_GROUP_CONVERSATION: '/conversations/group'
    POST_MESSAGE: '/conversations/{@}/messages'
    GET_CONVERSATIONS: '/conversations'
    GET_PROFILE: '/users/profile'

  # The Oauth permissions needed for the adapter
  OAUTH_PERMISSIONS ='ALL'

  constructor: ->
    super
    @log = @robot.logger
    @log.info 'Loading Circuit Adapter'

    @conf =
      clientId: process.env.HUBOT_CIRCUIT_CLIENT_ID
      clientSecret: process.env.HUBOT_CIRCUIT_CLIENT_SECRET
      circuitDomain: process.env.HUBOT_CIRCUIT_REST_API_URL or 'https://eu.yourcircuit.com/rest'
      scope: process.env.HUBOT_CIRCUIT_SCOPE or OAUTH_PERMISSIONS
      hubotHost: process.env.HUBOT_CIRCUIT_ADDRESS or process.env.EXPRESS_BIND_ADDRESS or '0.0.0.0'
      hubotWebhooksUrl: process.env.HUBOT_CIRCUIT_WEBHOOKS_URL
      hubotPort: process.env.HUBOT_CIRCUIT_PORT or process.env.PORT

  send: (envelope, strings...) ->
    @log.debug 'Send'

    for str in strings
      @postMessage(envelope, str)

  reply: (envelope, strings...) ->
    @log.debug 'Reply'
    @send envelope, strings...

  run: ->
    @log.debug 'Run'

    unless @conf.hubotWebhooksUrl and
    @conf.clientId and @conf.clientSecret

      @log.error \
        'Not enough parameters provided. ' +
        'I need a webhook url, a clientId & clientSecret'
      process.exit(1)
      return

    @setupExpress()

    # default configuration for http requests
    defaults =
      headers:
        'Content-Type': 'application/json'
      baseUrl: @conf.circuitDomain

    request = request.defaults defaults

    @retrieveToken().then () =>

      @log.info 'token retrieved'
      return @registerWebhook()
    .then () =>

      @log.info 'webhooks registered'
      return @getProfile()
    .then (profile) =>

      @log.info 'bot\'s profile retrieved'
      @robot.name = profile.displayName
      @robot.userId = profile.userId
      @emit 'connected'
    .catch (err) =>
      @log.error 'Promise exception', err
      @robot.emit 'error', err

  # Retrieves a token
  retrieveToken: () ->

    return new Promise (resolve, reject) =>
      @log.debug 'retrieve token'

      options =
        uri: URL.GET_TOKEN
        auth:
          user: @conf.clientId
          pass: @conf.clientSecret
        body: JSON.stringify
          grant_type : 'client_credentials',
          client_id  : @conf.clientId,
          client_secret : @conf.clientSecret,
          scope: @conf.scope

      @log.info 'sending http to:', options.uri
      # Get access token
      request.post options, (err, res, body) =>

        if err or res.statusCode > 400
          @log.error "error: #{err}, statusCode: #{res.statusCode}, #{body}"
          reject(err)
          return

        data = JSON.parse(body)
        @log.debug 'token', data.access_token

        @robot.token = data.access_token
        # add to defaults the access token
        request = request.defaults
          headers: 'Authorization': 'Bearer '+ @robot.token
        resolve()

  # Gets bot's profile
  getProfile: () ->

    return new Promise (resolve, reject) =>
      @log.debug 'get profile'

      request.get uri: URL.GET_PROFILE, (err, res, body) =>

        if err or res.statusCode > 400
          @log.error "error: #{err}, statusCode: #{res.statusCode}, #{body}"
          reject(err)
          return

        profile = JSON.parse body
        resolve(profile)

  # Register Webhook
  registerWebhook: () ->

    return @getWebhook().then (webhook) =>

      webhookUrl = @conf.hubotWebhooksUrl + '/hubot'
      matchedWebhook = (webhook.find (i) -> i.url is webhookUrl) if webhook?

      if matchedWebhook
        @log.info 'webhook with this url already exists'
        return

      return @addWebhook()

  # Get Webhooks
  getWebhook: ->

    return new Promise (resolve, reject) =>
      @log.debug 'Get webhooks'

      url = URL.WEBHOOK

      @log.info 'sending http to:', url
      request.get url, (err, res, body) =>

        if err or res.statusCode > 400
          @log.error "error: #{err}, statusCode: #{res.statusCode}, #{body}"
          reject(err)
          return

        webhook = JSON.parse(body)
        resolve(webhook)

  # Add Webhook
  addWebhook: ->

    return new Promise (resolve, reject) =>
      filters = 'CONVERSATION.ADD_ITEM,CONVERSATION.UPDATE_ITEM'
      webhookUrl = @conf.hubotWebhooksUrl + '/hubot'

      options =
        uri: URL.WEBHOOK
        body: JSON.stringify
          url: webhookUrl
          filter: filters

      @log.info 'sending http to', options.uri
      # Register webhooks
      request.post options, (err, res, body) =>

        if err or res.statusCode > 400
          @log.error "error: #{err}, statusCode: #{res.statusCode}, #{body}"
          reject(err)
          return

        resolve()

  # Setup an express
  setupExpress: ->
    @log.debug 'setupExpress to listen for webhooks'

    @app = express()
    @app.use(bodyParser.json())
    @app.post '/hubot', (req, res) =>

      @log.debug 'header', req.headers
      data = req.body

      unless data?.type
        res.sendStatus 400
        return

      @log.info "Event #{data.type} received"

      if data.type in
      ['itemAdded', 'CONVERSATION.ADD_ITEM', 'itemUpdated', 'CONVERSATION.UPDATE_ITEM']

        item = data.item
        text = item.text
        @log.info "Item sent from user with id #{item.creatorId} "+
          "to conversation with id #{item.convId}"

        if @robot.userId is item.creatorId
          @log.debug 'OOPS! I sent that msg. I won\'t reply to myself'
          res.sendStatus 403
          return

        unless text.content
          res.sendStatus 400
          return

        content = text.content
        if content?.includes('span')
          reg = new RegExp('<span.*">@')
          content = content.replace(reg, '').split('</span>').join()


        user = new User item.creatorId
        user.room = item.convId
        message = new TextMessage user, content, text.itemId
        message.parentId = if text.parentId then text.parentId else item.itemId

        # Dispatch the message
        @log.info "#{@robot.name} dispatches the msg"
        @robot.receive message
        res.sendStatus 200
      else
        res.sendStatus 400

    httpsOptions = null
    try
      key = fs.statSync 'key.pem'
      cert = fs.statSync 'cert.pem'

      httpsOptions =
        key: fs.readFileSync('key.pem')
        cert: fs.readFileSync('cert.pem')

    catch err
      @log.info 'Certificates do not exist.'

    @server = if httpsOptions then \
    https.createServer(httpsOptions, @app).listen(443, @conf.hubotHost) else\
    http.createServer(@app).listen(@conf.hubotPort || 8181, @conf.hubotHost)

  # Posts a message
  postMessage: (envelope, message) ->
    @log.debug 'Post message'

    convId = envelope?.room
    if not convId
      @log.error 'Conversation id is required'
      return

    parentId = envelope.message?.parentId
    subject = envelope.subject

    url = URL.POST_MESSAGE.replace('{@}', convId)
    data = JSON.stringify( content: message, subject: subject )

    options =
      uri: unless parentId then url else url + "/#{parentId}"
      body: data

    @log.info 'sending http to:', options.uri
    request.post options, (err, res, body) =>

      if err or res.statusCode > 400
        @log.error "error: #{err}, statusCode: #{res.statusCode}, #{body}"
        return

      @log.debug 'Body:', body
      data = JSON.parse(body)

exports.use = (robot) ->
  new CircuitBot robot

# used from tests
exports.Circuit = CircuitBot