export async function verifyGame(client, deployment, keccak256) {
  const [chainId, code] = await Promise.all([
    client.getChainId(),
    client.getCode({ address: deployment.contract }),
  ]);
  if (chainId !== deployment.chainId || !code || code === '0x' || keccak256(code) !== deployment.runtimeCodeHash) {
    throw new Error('Contract verification failed. Transactions are disabled. Check the confirmed deployment.');
  }
}
