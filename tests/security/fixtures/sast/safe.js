// Safe counterpart for the isolated Phase 03 fixture.
function selectOperation(operation, values) {
  const operations = { sum: (items) => items.reduce((total, value) => total + value, 0) };
  return operations[operation]?.(values);
}

module.exports = { selectOperation };
