export const CHAIN_ID = 1;
export const PREVIOUS_CONTRACT = '0x37cb0333a2fea358ae057bd85c4437803e5bcbfa';

export function validateDeployment(value) {
  if (!value || typeof value !== 'object' || value.chainId !== CHAIN_ID) {
    throw new Error('The deployment must be on Ethereum (chain 1).');
  }
  if (typeof value.contract !== 'string' || !/^0x[0-9a-fA-F]{40}$/.test(value.contract)) {
    throw new Error('A confirmed contract address is required.');
  }
  const address = value.contract.toLowerCase();
  if ([PREVIOUS_CONTRACT, '0x' + '0'.repeat(40), '0x' + '0'.repeat(36) + 'dead'].includes(address)) {
    throw new Error('The new game requires a fresh, confirmed contract address.');
  }
  if (typeof value.runtimeCodeHash !== 'string' || !/^0x[0-9a-fA-F]{64}$/.test(value.runtimeCodeHash) || /^0x0+$/.test(value.runtimeCodeHash)) {
    throw new Error('A verified runtime code hash is required.');
  }
  if (typeof value.deploymentBlock !== 'string' || !/^[1-9][0-9]*$/.test(value.deploymentBlock)) {
    throw new Error('The confirmed deployment block is required.');
  }
  return Object.freeze({
    chainId: CHAIN_ID,
    contract: address,
    runtimeCodeHash: value.runtimeCodeHash.toLowerCase(),
    deploymentBlock: value.deploymentBlock,
  });
}

export async function loadDeployment(fetcher) {
  const response = await fetcher(new URL('./deployment.json', import.meta.url), { cache: 'no-store' });
  if (!response.ok) throw new Error('The new deployment has not been connected to this website yet.');
  return validateDeployment(await response.json());
}
