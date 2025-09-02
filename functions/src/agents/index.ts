/**
 * Main export file for OpenAI Agents
 * Exports the properly implemented agents using the official SDK patterns
 */

export * from './grocery-agents-proper';
export { default as groceryAgents } from './grocery-agents-proper';

// Re-export main functions for easy access
export { 
  processGroceryRequest,
  updateInventoryWithConfirmation,
  mainAgent,
  inventoryAgent,
  recipeAgent,
  shoppingAgent
} from './grocery-agents-proper';