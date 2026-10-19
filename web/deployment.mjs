import { loadDeployment } from './config-schema.mjs';

// Confirmed Ethereum deployment from the pinned launch handoff. Verified by tools/verify_deployment.mjs.
export const deployment = await loadDeployment(fetch);
