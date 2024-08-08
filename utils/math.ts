/**
 * convert number to bigint
 * @param n number
 * @param decimals decimals, default 9
 * @returns bigint
 */
export function n2b(n: number, decimals: number | bigint = 9): bigint {
  const dn = Number(decimals);
  // do not use toFixed here, toFixed has Floating-point traps issue
  const ns = n.toString();
  let [int, dec] = ns.split(".");
  if (int === "0") int = "";
  if (!dec) dec = "";
  if (dec.length <= dn) {
    dec = dec.padEnd(dn, "0");
  } else {
    dec = dec.slice(0, dn);
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
  const dn = Number(decimals);
  const bs = b.toString(10);
  if (bs.length <= dn) {
    return parseFloat(`0.${bs.padStart(dn, "0")}`);
  } else {
    return parseFloat(
      `${bs.slice(0, bs.length - dn)}.${bs.slice(bs.length - dn)}`,
    );
  }
}
