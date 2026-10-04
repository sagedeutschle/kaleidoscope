#!/usr/bin/env node
// uncle-scam-golden.mjs: writes the answers the apps' Uncle Scam must reproduce, from the website's own arithmetic.
//
//   node scripts/uncle-scam-golden.mjs <path to a checkout of sagedeutschle/Bayzyl>
//
// It imports showcase/prismet-site/pages/scam-calc.js (the code prismet.xyz/scam runs), feeds it the site's data
// files, and writes:
//   shared/PrismetShared/Tests/PrismetSharedTests/Golden/uncle-scam-golden.json   the answers
//   shared/PrismetShared/Sources/PrismetShared/UncleScam/Bundled/tax-2026.json    the same data, bundled as the
//   shared/PrismetShared/Sources/PrismetShared/UncleScam/Bundled/mts-snapshot.json apps' offline fallback
// UncleScamGoldenTests.swift holds the Swift port to these answers, to the cent. Run this again whenever the site's
// data or arithmetic changes, and the tests say whether the apps still agree with the website.
import { readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const site = process.argv[2];
if (!site) { console.error('usage: node scripts/uncle-scam-golden.mjs <Bayzyl checkout>'); process.exit(1); }
const HERE = dirname(fileURLToPath(import.meta.url));
const PAGES = join(site, 'showcase/prismet-site/pages');
const SHARED = join(HERE, '../shared/PrismetShared');
const calc = await import(join(PAGES, 'scam-calc.js'));
const tax = JSON.parse(readFileSync(join(PAGES, 'scam-data/tax-2026.json'), 'utf8'));
const snapshot = JSON.parse(readFileSync(join(PAGES, 'scam-data/mts-snapshot.json'), 'utf8'));
const congress = JSON.parse(readFileSync(join(PAGES, 'scam-data/congress.json'), 'utf8'));
const shard = (zip) => JSON.parse(readFileSync(join(PAGES, 'scam-data/zip', `${zip.slice(0, 3)}.json`), 'utf8'))[zip] || null;
const st = calc.pickStatement(snapshot.rows);
// scam.js is the page's own script; outside a browser it only defines its functions
const page = await import(join(PAGES, 'scam.js'));
const usd = (n) => n.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
const usd2 = (n) => n.toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 2 });

const WAGES = [0, 1, 9000, 16100, 18250.55, 32000, 48475, 60000, 100000, 184500, 200000, 250000, 255000, 640600, 1000000, 3000000];
const STATES = ['OH', 'CA', 'NY', 'TX', 'WA', 'NJ', 'UT', 'AR', 'DC', 'MS', 'MD', 'HI', 'ND'];
const bills = [];
for (const stateCode of STATES) for (const status of ['single', 'joint', 'head']) for (const wages of WAGES) {
  const b = calc.computeBill({ wages, status, stateCode }, tax), t = calc.timeUnits(b, tax.federal.year);
  bills.push({ wages, status, state: stateCode, federalIncome: b.federalIncome, socialSecurity: b.socialSecurity, medicare: b.medicare, stateTax: b.state,
    federalTotal: b.federalTotal, total: b.total, takeHome: b.takeHome, marginal: b.marginal, borrowed: calc.borrowedFor(b.federalTotal, st),
    dayOfYear: t.dayOfYear, freedomDay: t.freedomDay, minutesPerWorkday: t.minutesPerWorkday, perPaycheck: t.perPaycheck });
}
const sha = (() => { try { return execFileSync('git', ['-C', site, 'rev-parse', '--short', 'HEAD']).toString().trim(); } catch { return 'unknown'; } })();
const golden = {
  _readme: 'Written by scripts/uncle-scam-golden.mjs from the website\'s scam-calc.js. Do not edit by hand.',
  site: sha, taxDataBuilt: tax.built,
  statement: { date: st.date, fiscalYear: st.fiscalYear, months: st.months, outlays: st.outlays, receipts: st.receipts, borrowedPerDollar: st.borrowedPerDollar },
  bills,
  splits: [0.01, 1, 5020, 123456.78].map((amount) => ({ amount, lines: calc.splitByFunction(amount, st).map((l) => ({ name: l.name, amount: l.amount, rest: l.rest === true })) })),
  zips: ['43201', '10001', '90210', '60601', '77002', '98101', '20001', '99501', '96813', '03579', '00901', '00000', '4320', 'abcde'].map((zip) => ({ zip, place: calc.placeForZip(zip, tax) })),
  officials: ['43201', '43206', '82001', '20001'].map((zip) => {
    const place = calc.placeForZip(zip, tax), o = calc.officialsFor(shard(zip), place.code, congress);
    return { zip, entry: shard(zip), state: place.code, senators: o.senators.map((m) => m.n), seats: o.seats.map((s) => ({ state: s.state, district: s.district, member: s.member ? s.member.n : null })) };
  }),
  fiscalYears: ['2026-10-03', '2026-09-30', '2027-01-15', '2026-10-01'].map((today) => ({ today, ...calc.lastFiscalYear(today) })),
  receipts: [[60000, 'single', 'OH'], [250000, 'joint', 'CA'], [32000, 'head', 'TX'], [1240.5, 'single', 'WA']].flatMap(([wages, status, stateCode]) => [false, true].map((percent) => ({
    wages, status, state: stateCode, percent,
    rows: page.receiptRows(calc.computeBill({ wages, status, stateCode }, tax), st, tax, percent).map((r) => ({ kind: r.k, text: r.t ?? r.l ?? '', value: r.r ?? '', style: r.c ?? '' })),
  }))),
  formats: {
    usd: [0, 0.4, 0.5, 1240.5, 1241.5, 999.5, 60000, 1234567.49, 3898.335].map((n) => [n, usd(n)]),
    usd2: [0, 1.405, 1.4057, 0.005, 12.345, 1.41].map((n) => [n, usd2(n)]),
    pct: [0, 0.1725, 0.17463, 0.0035, 0.99995, 1].map((n) => [n, `${(n * 100).toFixed(1)}%`]),
    big: [1643e10, 40260641972390, 10511777950.94, 309565499.61, 842625, 999999.5].map((n) => [n, page.big(n)]),
    salary: ['65,000', '$65000', '65k', '1.2m', ' $ 48,250.75 ', 'abc', '', '-5', '1,2.3.4'].map((t) => [t, Number.isNaN(page.parseSalary(t)) ? null : page.parseSalary(t)]),
  },
  names: ['OHIO STATE UNIVERSITY, THE', 'BATTELLE MEMORIAL INSTITUTE', 'ACME  WIDGETS OF OHIO LLC', "O'NEIL-SMITH & SONS", 'REDACTED DUE TO PII', 'MULTIPLE RECIPIENTS', 'DIRCKSEN & ASSOCIATES, INC.'].map((raw) => ({ raw, tidy: calc.tidyName(raw) })),
};
writeFileSync(join(SHARED, 'Tests/PrismetSharedTests/Golden/uncle-scam-golden.json'), JSON.stringify(golden) + '\n');
for (const f of ['tax-2026.json', 'mts-snapshot.json']) copyFileSync(join(PAGES, 'scam-data', f), join(SHARED, 'Sources/PrismetShared/UncleScam/Bundled', f));
// the member list as the tests saw it (the apps fetch the live one)
writeFileSync(join(SHARED, 'Tests/PrismetSharedTests/Golden/uncle-scam-congress.json'), JSON.stringify(congress) + '\n');
console.log(`uncle-scam golden: ${bills.length} bills, ${golden.splits.length} splits, site ${sha}, tax data ${tax.built}`);
