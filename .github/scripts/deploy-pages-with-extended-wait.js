const POLL_INTERVAL_MS = 5000;
const DEFAULT_TIMEOUT_MS = 30 * 60 * 1000;
const MAX_STATUS_ERRORS = 10;

const finalFailureStatuses = new Set([
  'deployment_failed',
  'deployment_perms_error',
  'deployment_content_failed',
  'deployment_cancelled',
  'deployment_lost',
]);

const wait = (milliseconds) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));

module.exports = async function deployPages({ github, context, core }) {
  const artifactId = Number(process.env.PAGES_ARTIFACT_ID);
  const timeoutMs = Number(
    process.env.PAGES_DEPLOYMENT_TIMEOUT_MS || DEFAULT_TIMEOUT_MS,
  );

  if (!Number.isSafeInteger(artifactId) || artifactId <= 0) {
    throw new Error('PAGES_ARTIFACT_ID is missing or invalid.');
  }
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new Error('PAGES_DEPLOYMENT_TIMEOUT_MS is invalid.');
  }

  const owner = context.repo.owner;
  const repo = context.repo.repo;
  const buildVersion = context.sha;
  const oidcToken = await core.getIDToken();

  const response = await github.request(
    'POST /repos/{owner}/{repo}/pages/deployments',
    {
      owner,
      repo,
      artifact_id: artifactId,
      pages_build_version: buildVersion,
      oidc_token: oidcToken,
    },
  );

  const deployment = response.data;
  const deploymentId =
    deployment.id ||
    deployment.status_url?.split('/').pop() ||
    buildVersion;
  const pageUrl =
    deployment.page_url || `https://${owner}.github.io/${repo}/`;
  const deadline = Date.now() + timeoutMs;
  let statusErrors = 0;
  let lastStatus;

  core.setOutput('page_url', pageUrl);
  core.info(`Created Pages deployment for ${buildVersion}.`);

  while (Date.now() < deadline) {
    await wait(POLL_INTERVAL_MS);

    try {
      const statusResponse = await github.request(
        'GET /repos/{owner}/{repo}/pages/deployments/{deploymentId}',
        { owner, repo, deploymentId },
      );
      const status = statusResponse.data.status;
      statusErrors = 0;

      if (status !== lastStatus) {
        core.info(`Pages deployment status: ${status}`);
        lastStatus = status;
      }

      if (status === 'succeed') {
        core.setOutput('status', status);
        core.setOutput('page_url', statusResponse.data.page_url || pageUrl);
        return;
      }

      if (finalFailureStatuses.has(status)) {
        throw new Error(`GitHub Pages deployment failed: ${status}.`);
      }
    } catch (error) {
      if (error.message.startsWith('GitHub Pages deployment failed:')) {
        throw error;
      }

      statusErrors += 1;
      core.warning(
        `Unable to read Pages deployment status (${statusErrors}/${MAX_STATUS_ERRORS}): ${error.message}`,
      );
      if (statusErrors >= MAX_STATUS_ERRORS) {
        throw error;
      }
    }
  }

  try {
    await github.request(
      'POST /repos/{owner}/{repo}/pages/deployments/{deploymentId}/cancel',
      { owner, repo, deploymentId },
    );
  } catch (error) {
    core.warning(`Unable to cancel timed-out Pages deployment: ${error.message}`);
  }

  throw new Error(
    `GitHub Pages deployment did not finish within ${timeoutMs} ms (last status: ${lastStatus || 'unknown'}).`,
  );
};
