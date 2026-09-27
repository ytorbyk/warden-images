import * as core from '@actions/core';
import * as semver from 'semver';

const PHP_BRANCHES_URL = 'https://www.php.net/releases/branches.php';
const ABSOLUTE_MINIMUM_VERSION = '7.4';

export async function run() {
    try {
        const data = {
            "eol": {
                "major": [],
                "minor": []
            },
            "security": {
                "major": [],
                "minor": []
            },
            "stable": {
                "major": [],
                "minor": []
            }
        };

        const branches = await getPHPBranches();
        const versionConstraint = core.getInput('version-constraint');

        for (const { branch: minorVer, latest, state } of branches) {
            if (!semver.gte(semver.coerce(minorVer), semver.coerce(ABSOLUTE_MINIMUM_VERSION))) {
                core.info(`Skipping ${minorVer} as it is below the minimum version ${ABSOLUTE_MINIMUM_VERSION}`);
                continue;
            }

            if (!Object.hasOwn(data, state)) {
                core.warning(`Skipping ${minorVer} as it reports the unknown state '${state}'`);
                continue;
            }

            if (!semver.valid(semver.coerce(latest))) {
                core.warning(`Skipping ${minorVer} as it reports the unusable latest release '${latest}'`);
                continue;
            }

            if (
                !versionConstraint
                || semver.satisfies(semver.coerce(minorVer), versionConstraint)
            ) {
                data[state].major.push(minorVer);
                data[state].minor.push(latest);
            }
        }

        for (const [state, details] of Object.entries(data)) {
            core.info(`PHP ${state} versions: ${details.minor.join(', ') || '(none)'}`);
            core.setOutput(`php_${state}_versions`, JSON.stringify(details));
        }
    } catch (error) {
        core.setFailed(error instanceof Error ? error.message : String(error));
    }
}

async function getPHPBranches() {
    const branches = await fetchJSON(PHP_BRANCHES_URL);

    if (!Array.isArray(branches)) {
        throw new Error(`Expected ${PHP_BRANCHES_URL} to return an array of branches`);
    }

    // The endpoint lists the newest branch first and carries a few legacy
    // entries without a usable version, so drop those and sort ascending to
    // keep the outputs in a predictable order.
    return branches
        .filter((branch) => branch && semver.valid(semver.coerce(branch.branch)))
        .sort((a, b) => semver.compare(semver.coerce(a.branch), semver.coerce(b.branch)));
}

async function fetchJSON(url, attempts = 3, retryDelay = 2000) {
    let lastError;

    for (let attempt = 1; attempt <= attempts; attempt++) {
        try {
            const response = await fetch(url);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status} ${response.statusText}`);
            }

            const body = await response.text();

            if (body.trim() === '') {
                throw new Error('empty response body');
            }

            return JSON.parse(body);
        } catch (error) {
            lastError = error;

            if (attempt < attempts) {
                core.warning(`Fetching ${url} failed (attempt ${attempt}/${attempts}): ${lastError.message}`);
                await new Promise((resolve) => setTimeout(resolve, retryDelay));
            }
        }
    }

    throw new Error(`Unable to fetch ${url} after ${attempts} attempts: ${lastError.message}`);
}
