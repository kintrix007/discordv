module discordv

import math
import net.urllib
import json
import x.json2
import discordv.rest
import discordv.rest.formdata

// Optional query for guild_audit_log.
// 'limit' must be [1, 100], default 50.
pub struct GuildAuditLogQuery {
	user_id     string
	action_type AuditLogEvent
	before      string
	limit       int = 50
}

pub fn (query GuildAuditLogQuery) query() string {
	mut values := urllib.new_values()
	if query.user_id != '' {
		values.add('user_id', query.user_id)
	}
	if query.action_type.str() != 'unknown enum value' {
		values.add('action_type', query.action_type.str())
	}
	if query.before != '' {
		values.add('before', query.before)
	}
	values.add('limit', math.min(math.max(1, query.limit), 100).str())
	return values.encode()
}

// Returns an AuditLog struct for the guild. Requires the 'VIEW_AUDIT_LOG' permission.
pub fn (mut client Client) guild_audit_log(guild_id string, query GuildAuditLogQuery) !AuditLog {
	path := '/guilds/${guild_id}/audit-logs'
	mut req := client.rest.req(.get, path) or {
		return error('Could not make GET request to ${path}')
	}
	req.url += '${query.query()}'

	resp := client.rest.do(req)!
	if resp.status_code != 200 {
		response_error := unsafe { rest.ResponseCode(resp.status_code) }
		err_text := 'Status code is ${resp.status_code} (${response_error}).\n'
		client.log.error(err_text + 'Request: ${req.data}')
		return error(err_text)
	}

	return json.decode(AuditLog, resp.body) or {}
}

// MessageSend stores all parameters you can send with channel_message_send.
pub struct MessageSend {
pub mut:
	content   string
	embed     Embed
	tts       bool
	file      File
	nonce     string
	reference MessageReference
}

pub fn (ms MessageSend) to_json() json2.Any {
	mut obj := map[string]json2.Any{}
	obj['content'] = ms.content
	obj['nonce'] = ms.nonce
	obj['tts'] = ms.tts
	if !ms.embed.iszero() {
		obj['embed'] = ms.embed.to_json()
	}
	if !ms.reference.iszero() {
		obj['message_reference'] = ms.reference.to_json()
	}
	return obj
}

// Post a message to a guild text or DM channel. If operating on a guild channel, this endpoint requires the SEND_MESSAGES permission to be present on the current user.
pub fn (mut client Client) channel_message_send(channel_id string, message MessageSend) ! {
	path := '/channels/${channel_id}/messages'
	mut req := client.rest.req(.post, path) or {
		return error('Could not make POST request to ${path}')
	}

	if message.file.filename != '' {
		mut form := formdata.new() or { return error('') }
		req.add_header(.content_type, form.content_type())
		form.add('payload_json', message.to_json().str())
		form.add_file('file', message.file.filename, message.file.data)
		req.data = form.encode()
	} else {
		req.add_header(.content_type, 'application/json')
		req.data = message.to_json().str()
	}

	resp := client.rest.do(req)!
	if resp.status_code != 200 {
		response_error := unsafe { rest.ResponseCode(resp.status_code) }
		err_text := 'Status code is ${resp.status_code} (${response_error}).\n'
		client.log.error(err_text + 'Request: ${req.data}')
		return error(err_text)
	}
}

// Delete message from a channel
pub fn (mut client Client) channel_message_delete(channel_id string, message_id string) ! {
	path := '/channels/${channel_id}/messages/${message_id}'
	mut req := client.rest.req(.delete, path) or {
		return error('Could not make DELETE request to "${path}"')
	}

	resp := client.rest.do(req)!
	if resp.status_code != 204 {
		response_error := unsafe { rest.ResponseCode(resp.status_code) }
		err_text := 'Status code is ${resp.status_code} (${response_error}).\n'
		return error(err_text)
	}
}
