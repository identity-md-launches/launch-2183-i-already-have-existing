import { loadDeployment } from './config-schema.mjs';

// Written by tools/build_site.py only after the launch service supplies a confirmed deployment.
export const deployment = await loadDeployment(fetch);
