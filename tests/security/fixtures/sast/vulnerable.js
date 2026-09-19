// Deliberately vulnerable, isolated Phase 03 fixture. Never use this pattern in application code.
function evaluateUserInput(userInput) {
  return eval(userInput);
}

module.exports = { evaluateUserInput };
