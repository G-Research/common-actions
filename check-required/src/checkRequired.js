const core = require('@actions/core');
const github = require('@actions/github');

async function run() {
    try {
        const githubToken = core.getInput('github-token');
        core.info(`GitHub token: ${githubToken ? '***' : 'undefined'}`);

        // This is the official Github Actions app id
        const ghaAppId = 15368;
        const ghaName = 'All required checks done'; // TODO make this configurable

        const myName = 'All required checks succeeded';
        const owner = github.context.payload.repository.owner.login;
        const repo = github.context.payload.repository.name;
        const sha = github.context.payload.workflow_run.head_sha;

        const octokit = github.getOctokit(githubToken);

        core.info(`List GitHub Actions check runs for ${sha}.`);
        const { data: { check_runs: ghaChecks } } = await octokit.rest.checks.listForRef({
            owner: owner,
            repo: repo,
            ref: sha,
            app_id: ghaAppId,
            check_name: ghaName,
        });

        var newCheck = {
            owner: owner,
            repo: repo,
            name: myName,
            head_sha: sha,
            status: 'in_progress',
            started_at: github.context.payload.workflow_run.created_at,
            output: {
                title: 'Not all required checks succeeded',
            },
        };

        core.summary.addHeading('The following required checks have been considered:', 3);
        ghaChecks.forEach(check => {
            core.summary
                .addLink(check.name, check.html_url)
                .addCodeBlock(JSON.stringify(check, ['status', 'conclusion', 'started_at', 'completed_at'], 2), 'json');

            if (check.status === 'completed' && check.conclusion === 'success') {
                newCheck.status = 'completed';
                newCheck.conclusion = 'success';
                newCheck.started_at = check.started_at;
                newCheck.completed_at = check.completed_at;
                newCheck.output.title = 'All required checks succeeded';
            } else if (check.started_at > newCheck.started_at) {
                newCheck.started_at = check.started_at;
            }
        });
        if (ghaChecks.length === 0) {
            core.summary.addRaw(`No check runs for ${sha} found.`);
        }
        newCheck.output.summary = core.summary.stringify();
        await core.summary.write();

        core.info(`Create own check run for ${sha}: ${JSON.stringify(newCheck, null, 2)}.`);
        const { data: { html_url } } = await octokit.rest.checks.create(newCheck);

        await core.summary
            .addHeading('Check run created:', 3)
            .addLink(myName, html_url)
            .addCodeBlock(JSON.stringify(newCheck, null, 2), 'json')
            .write();

        core.setOutput('result', 'success');

    } catch (error) {
        core.setFailed(`Failed to run the action. Error message is: ${error.message}`);
    }
}

run();
