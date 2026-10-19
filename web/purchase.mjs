/** @param {import('./types.js').Game} game @param {bigint} roundId @param {bigint} count @param {bigint} cost */
function checkGame(game, roundId, count, cost) {
  if (game.mode !== 'future-blockhash') throw new Error('The fresh future-blockhash deployment is required.');
  if (!game.configured || !game.token) throw new Error('IMD is not configured. Entries are closed.');
  if (game.paused) throw new Error('Entries are paused. Claims and eligible refunds remain available.');
  if (game.round.status === 2) throw new Error('The draw is in progress. Entries reopen in the next round.');
  if (game.round.status > 2 || (game.round.status === 1 && game.chainTime >= Number(game.round.endTime))) {
    throw new Error('Tickets are closed. Anyone can finalize this round.');
  }
  if (game.roundId !== roundId || game.ticketPrice * count !== cost) {
    throw new Error('The round or ticket cost changed. Review your purchase again.');
  }
}

// The host submits through its existing simulation, wallet/account check, and confirmed-receipt flow.
// Approval and purchase are separate confirmations; every rejection propagates to that flow's error UI.
/** @param {import('./types.js').Purchase} options */
export async function buyReviewedTickets({ count, roundId, cost, loadGame, loadBalance, loadAllowance, approve, buy }) {
  if (typeof count !== 'bigint' || count < 1n || count > 1_000_000n) throw new Error('Invalid ticket count.');
  const game = await loadGame();
  checkGame(game, roundId, count, cost);
  if (!game.token) throw new Error('IMD is not configured. Entries are closed.');
  const [balance, allowance] = await Promise.all([loadBalance(game.token), loadAllowance(game.token)]);
  if (balance < cost) throw new Error('Not enough IMD for this purchase. Choose fewer tickets.');
  if (allowance < cost) await approve(game.token, cost);
  checkGame(await loadGame(), roundId, count, cost);
  await buy(roundId, count);
  return `${count.toLocaleString('en-US')} ${count === 1n ? 'ticket is' : 'tickets are'} confirmed in round #${roundId}. Good luck.`;
}
