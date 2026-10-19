/** Types for the existing application's audited deployment, read and purchase boundary. */
export type Hex = `0x${string}`;
export interface Deployment {
  readonly chainId: number;
  readonly contract: Hex;
  readonly runtimeCodeHash: Hex;
  readonly deploymentBlock: string;
}
export interface Round {
  status: number;
  endTime?: bigint;
  drawBlock?: bigint;
}
export interface Game {
  mode: string;
  configured: boolean;
  token?: Hex;
  paused: boolean;
  roundId: bigint;
  ticketPrice: bigint;
  chainTime: number;
  round: Round;
}
export interface Purchase {
  count: bigint;
  roundId: bigint;
  cost: bigint;
  loadGame: () => Promise<Game>;
  loadBalance: (token: Hex) => Promise<bigint>;
  loadAllowance: (token: Hex) => Promise<bigint>;
  approve: (token: Hex, amount: bigint) => Promise<unknown>;
  buy: (roundId: bigint, count: bigint) => Promise<unknown>;
}
