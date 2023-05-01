import tiktoken


def num_tokens_in_single_message(message, model="gpt-3.5-turbo"):
	"""Returns the number of tokens used by a list of messages."""
	encoding = tiktoken.encoding_for_model(model)
	if model == "gpt-3.5-turbo":
		print("Warning: gpt-3.5-turbo may change over time. Returning num tokens assuming gpt-3.5-turbo-0301.")
		return num_tokens_in_single_message(message, model="gpt-3.5-turbo-0301")
	elif model == "gpt-4":
		print("Warning: gpt-4 may change over time. Returning num tokens assuming gpt-4-0314.")
		return num_tokens_in_single_message(message, model="gpt-4-0314")
	elif model == "gpt-3.5-turbo-0301":
		tokens_per_message = 4  # every message follows <|start|>{role/name}{content}<|end|>
		tokens_per_name = -1  # if there's a name, the role is omitted
	elif model == "gpt-4-0314":
		tokens_per_message = 3
		tokens_per_name = 1
	else:
		raise NotImplementedError(f"""num_tokens_in_single_message() is not implemented for model {model}. See https://github.com/openai/openai-python/blob/main/chatml.md for information on how messages are converted to tokens.""")
	num_tokens = 0
	num_tokens += tokens_per_message
	for key, value in message.items():
		num_tokens += len(encoding.encode(value))
		if key == "name":
			num_tokens += tokens_per_name
	return num_tokens


def num_tokens_from_messages(messages, model="gpt-3.5-turbo"):
	"""Returns the number of tokens used by a list of messages."""
	encoding = tiktoken.encoding_for_model(model)
	if model == "gpt-3.5-turbo":
		print("Warning: gpt-3.5-turbo may change over time. Returning num tokens assuming gpt-3.5-turbo-0301.")
		return num_tokens_from_messages(messages, model="gpt-3.5-turbo-0301")
	elif model == "gpt-4":
		print("Warning: gpt-4 may change over time. Returning num tokens assuming gpt-4-0314.")
		return num_tokens_from_messages(messages, model="gpt-4-0314")
	elif model == "gpt-3.5-turbo-0301":
		tokens_per_message = 4  # every message follows <|start|>{role/name}{content}<|end|>
		tokens_per_name = -1  # if there's a name, the role is omitted
	elif model == "gpt-4-0314":
		tokens_per_message = 3
		tokens_per_name = 1
	else:
		raise NotImplementedError(f"""num_tokens_from_messages() is not implemented for model {model}. See https://github.com/openai/openai-python/blob/main/chatml.md for information on how messages are converted to tokens.""")
	num_tokens = 0
	for message in messages:
		num_tokens += tokens_per_message
		for key, value in message.items():
			num_tokens += len(encoding.encode(value))
			if key == "name":
				num_tokens += tokens_per_name
	num_tokens += 3  # every reply is primed with <|start|>assistant<|message|>
	return num_tokens
