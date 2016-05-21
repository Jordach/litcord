local classes = require('../classes')
local base = require('./base')

local Invite = require('./Invite')
local Message = require('./Message')
local VoiceConnection = require('./VoiceConnection')

local Channel = classes.new(base)

function Channel:__constructor ()
	self.history = classes.Cache()
end

function Channel:__onUpdate ()
	self.isVoice = (not self.topic and not self.last_message_id)
end

function Channel:sendFile (file, content, options)
	options = options or {}
	options.file = file
	return self:sendMessage(content, options)
end

function Channel:sendMessage (content, options)
	options = options or {}
	options.content = content
	local data = self.parent.parent.rest:request(
		{
			method = 'POST',
			path = 'channels/'..self.id..'/messages',
			data = options,
		}
	)
	local message = Message(self, self.parent.parent.user)
	self.history:add(message)
	message:update(data)
	return message
end

function Channel:getInvites()
	if not self.invites then
		self.invites = classes.Cache()
		local invites = self.parent.rest:request(
			{
				method = 'GET',
				path = 'channels/'..self.id..'/invites',
			}
		)
		for _,v in ipairs(invites) do
			v.inviter = nil
			local invite = Invite(self)
			invite:update(v)
			self.invites:add(invite)
		end
	end
	return self.invites
end

function Channel:delete ()
	self.parent.parent.rest:request(
		{
			method = 'DELETE',
			path = 'channels/'..self.id,
		}
	)
end

function Channel:modify (config)
	self.parent.parent.rest:request(
		{
			method = 'PATCH',
			path = 'channels/'..self.id,
			data = { -- config, -- gives a bad request error, so no config directly..
				name = config.name or self.name,
				position = config.position or self.position,
				topic = config.topic or self.topic,
				bitrate = config.bitrate or self.bitrate,
			},
		}
	)
end
function Channel:setName (name)
	self:modify({name = name})
end
function Channel:setPosition (position)
	self:modify({position = position})
end
function Channel:setTopic (topic)
	self:modify({topic = topic})
end
function Channel:setBitrate (bitrate)
	self:modify({bitrate = bitrate})
end

-- Voice
function Channel:join ()
	if not self.isVoice or self.voiceConnection then return end
	self.voiceConnection = VoiceConnection(self)
end

function Channel:leave ()
	if not self.isVoice or not self.voiceConnection then return end
	self.voiceConnection:disconnect()
end

return Channel