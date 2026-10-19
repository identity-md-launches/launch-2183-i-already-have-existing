// Public chain facts copied from the pinned launch handoff, not wallet-specific settings.
export const network = Object.freeze({
  chainId: 1,
  name: 'Ethereum',
  rpcUrls: ['https://ethereum-rpc.publicnode.com', 'https://eth.drpc.org'],
  explorer: 'https://etherscan.io',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  token: '0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7',
});
