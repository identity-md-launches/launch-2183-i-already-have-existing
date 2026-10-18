export function roundClock(round, chainTime) {
  if (!round) return { text: '--:--', seconds: 0, label: 'Reading the round' };
  if (round.status === 0) return { text: '15:00', seconds: 900, label: 'Starts with the first ticket' };
  if (round.status === 2) return { text: '00:00', seconds: 0, label: 'Waiting for the draw' };
  const seconds = Math.max(0, Number(round.endTime) - Math.floor(chainTime));
  return {
    text: `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`,
    seconds,
    label: seconds > 0 ? 'Until tickets close' : 'Ready to finalize',
  };
}

export function parseTicketCount(input) {
  const value = input.trim();
  if (!/^\d+$/.test(value)) return { error: 'Enter a whole number of tickets.' };
  if (value.length > 7) return { error: 'Choose between 1 and 1,000,000 tickets.' };
  const count = BigInt(value);
  return count < 1n || count > 1_000_000n
    ? { error: 'Choose between 1 and 1,000,000 tickets.' }
    : { count };
}

export function drawState(round, head) {
  const target = round.drawBlock;
  const format = (number) => number.toLocaleString('en-US');
  if (round.status !== 2 || target === undefined) return {
    ready: false, expired: false, label: 'Finalize round',
    detail: 'Commit a block 3 blocks ahead, then return to settle the draw. Anyone can call both steps.',
  };
  if (head <= target) return {
    ready: false, expired: false, label: 'Waiting for target block',
    detail: `Target: block ${format(target)}. Settle after it is mined, through block ${format(target + 256n)}.`,
  };
  if (head > target + 256n) return {
    ready: false, expired: true, label: 'Draw expired',
    detail: 'The blockhash window has expired. Cancel this round in Round tools to enable full refunds.',
  };
  return {
    ready: true, expired: false, label: 'Settle winners',
    detail: `Block ${format(target)} is ready. Settle by block ${format(target + 256n)} to release prizes.`,
  };
}
