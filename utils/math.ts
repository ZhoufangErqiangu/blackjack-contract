/**
 * convert number to bigint
 * @param n number
 * @param decimals decimals, default 9
 * @returns bigint
 */
export function n2b(n: number, decimals: number | bigint = 9): bigint {
  const ns = n.toString();
  let [int, dec] = ns.split(".");
  if (int === "0") int = "";
  if (!dec) dec = "";
  if (dec.length <= Number(decimals)) {
    dec = dec.padEnd(Number(decimals), "0");
  } else {
    dec = dec.slice(0, Number(decimals));
  }
  return BigInt(`${int}${dec}`);
}

/**
 * convert bigint to number
 * @param b bigint
 * @param decimals decimals, default 9
 * @returns number
 */
export function b2n(b: bigint, decimals: number | bigint = 9): number {
  const bs = b.toString();
  if (bs.length <= Number(decimals)) {
    return parseFloat(`0.${bs.padStart(Number(decimals), "0")}`);
  } else {
    return parseFloat(
      `${bs.slice(0, bs.length - Number(decimals))}.${bs.slice(bs.length - Number(decimals))}`,
    );
  }
}
