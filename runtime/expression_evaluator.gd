extends RefCounted
class_name FKExpressionEvaluator

## FlowKit Expression Evaluator
## Evaluates string expressions at runtime into actual values
## Supports:
## - String literals: "Hello World!"
## - Numbers: 42, 3.14
## - Math expressions: 1+1, 5*3, 10/2
## - Boolean values: true, false
## - Variable access: $variable_name
## - Node properties: node.position.x

## Evaluates a string expression and returns the result
## Returns the evaluated value or the original string if evaluation fails
static func evaluate(expr_str: String, context_node: Node = null) -> Variant:
	if expr_str.is_empty():
		return ""
	
	# Trim whitespace
	expr_str = expr_str.strip_edges()
	
	# Check for string literals (enclosed in quotes)
	if _is_string_literal(expr_str):
		return _parse_string_literal(expr_str)
	
	# Check for boolean literals
	if expr_str.to_lower() == "true":
		return true
	if expr_str.to_lower() == "false":
		return false
	
	# Check for null
	if expr_str.to_lower() == "null":
		return null
	
	# Try to parse as a number
	if _is_numeric(expr_str):
		if "." in expr_str or "e" in expr_str.to_lower():
			return float(expr_str)
		else:
			return int(expr_str)
	
	# Try to evaluate as a GDScript expression
	var result: Variant = _evaluate_expression(expr_str, context_node)
	if result != null:
		return result
	
	# If all else fails, return as string
	return expr_str


## Check if the string is a quoted string literal
static func _is_string_literal(expr: String) -> bool:
	if expr.length() < 2:
		return false
	
	var starts_with_quote: bool = expr[0] == '"' or expr[0] == "'"
	var ends_with_quote: bool = expr[expr.length() - 1] == '"' or expr[expr.length() - 1] == "'"
	
	return starts_with_quote and ends_with_quote


## Parse a string literal, removing quotes and handling escape sequences
static func _parse_string_literal(expr: String) -> String:
	# Remove surrounding quotes
	var content: String = expr.substr(1, expr.length() - 2)
	
	# Handle escape sequences
	content = content.replace("\\n", "\n")
	content = content.replace("\\t", "\t")
	content = content.replace("\\\"", "\"")
	content = content.replace("\\'", "'")
	content = content.replace("\\\\", "\\")
	
	return content


## Check if a string represents a numeric value
static func _is_numeric(expr: String) -> bool:
	if expr.is_empty():
		return false
	
	# Handle negative numbers
	var check_str: String = expr
	if check_str[0] == "-":
		check_str = check_str.substr(1)
	
	# Simple validation: contains only digits, at most one decimal point, and optional 'e' for scientific notation
	var has_decimal: bool = false
	var has_e: bool = false
	
	for i in range(check_str.length()):
		var c: String = check_str[i]
		
		if c == ".":
			if has_decimal or has_e:
				return false
			has_decimal = true
		elif c.to_lower() == "e":
			if has_e or i == 0 or i == check_str.length() - 1:
				return false
			has_e = true
		elif c == "-" or c == "+":
			# Allow +/- only after 'e'
			if i == 0 or check_str[i - 1].to_lower() != "e":
				return false
		elif not c.is_valid_int():
			return false
	
	return true


## Evaluate a GDScript expression using the Expression class
static func _evaluate_expression(expr_str: String, context_node: Node) -> Variant:
	var expression: Expression = Expression.new()
	
	# Prepare input variables
	var input_names: Array = []
	var input_values: Array = []
	
	# If we have a context node, make it available as 'node'
	if context_node:
		input_names.append("node")
		input_values.append(context_node)
		
		# Also try to get FlowKitSystem for variable access
		if context_node.get_tree() and context_node.get_tree().root.has_node("/root/FlowKitSystem"):
			var system: Node = context_node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
			if system:
				input_names.append("system")
				input_values.append(system)
				
				# Make all variables directly accessible in expressions
				if "variables" in system and system.variables is Dictionary:
					for var_name in system.variables.keys():
						input_names.append(var_name)
						input_values.append(system.variables[var_name])
	
	# Parse the expression
	var error: Error = expression.parse(expr_str, input_names)
	if error != OK:
		# Expression parsing failed
		return null
	
	# Execute the expression (suppress error output to avoid console spam)
	var result: Variant = expression.execute(input_values, context_node, false)
	
	if expression.has_execute_failed():
		# Execution failed
		return null
	
	return result


## Convenience method to evaluate all inputs in a dictionary
## Returns a new dictionary with evaluated values
static func evaluate_inputs(inputs: Dictionary, context_node: Node = null) -> Dictionary:
	var evaluated: Dictionary = {}
	
	for key in inputs.keys():
		var value: Variant = inputs[key]
		
		# Only evaluate if the value is a string
		if value is String:
			evaluated[key] = evaluate(value, context_node)
		else:
			evaluated[key] = value
	
	return evaluated
