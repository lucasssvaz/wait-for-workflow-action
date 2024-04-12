# Wait on Workflow

[![Test Wait on Workflow](https://github.com/lucasssvaz/wait-on-workflow/actions/workflows/test.yml/badge.svg)](https://github.com/lucasssvaz/wait-on-workflow/actions/workflows/test.yml)

This GitHub Action waits on a specified workflow to complete before proceeding with the next steps in your workflow. It is useful when you have dependent workflows and want to ensure that one completes successfully before continuing with the next. For example, you might want to ensure that a build or test workflow finishes successfully before starting a deployment workflow.

This is a fork of the original [wait-for-workflow-action](https://github.com/kamilchodola/wait-for-workflow-action) by [@kamilchodola](https://github.com/kamilchodola), with some improvements and bug fixes. Thanks to the original author for the great work!

## Inputs

| Input           | Description                                                                     | Required | Default                  |
|-----------------|---------------------------------------------------------------------------------|----------|--------------------------|
| `github-token`  | GitHub token to access the repository and its APIs                              | No       | `${{github.token}}`      |
| `workflow`      | Run ID or file name of the workflow to wait on                                  | Yes      |                          |
| `max-wait`      | Maximum time the script will wait on the workflow run to be found (minutes)     | No       | `5`                      |
| `interval`      | Interval between checking workflow status (seconds)                             | No       | `10`                     |
| `timeout`       | Maximum time the script will wait on the workflow run to be finished (minutes)  | No       | `30`                     |
| `repository`    | Repository name with owner where the workflow is running                        | No       | `${{github.repository}}` |
| `sha`           | Head commit reference to watch for the workflow run                             | No       | `${{github.sha}}`        |
| `verbose`       | Enable verbose output                                                           | No       | `false`                  |

## Outputs

| Output       | Description                                                                                                                                  |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `run-id`     | ID of the workflow run                                                                                                                       |
| `conclusion` | Conclusion of the workflow run. Can be one of the `success`, `failure`, `neutral`, `cancelled`, `skipped`, `timed_out`, or `action_required` |

## How It Works

This action performs the following steps:

1. If the `workflow` provided is not a run ID, loop until the specified workflow is triggered:
   - Sends a request to the GitHub API to get the list of workflow runs for the specified `workflow`.
   - Filters the list of workflow runs based on the provided `sha` (head commit).
   - Checks if the maximum waiting time `max-wait` has been reached. If so, exits with an error message.
   - Sleeps for `interval` seconds before checking again if the workflow has been triggered.
2. Once the workflow is triggered, sets the `run-id` output and loops until the workflow run is completed:
   - Sends a request to the GitHub API to get the status of the specified workflow run.
   - Checks if the status is "completed". If so, proceeds to the next step.
   - Checks if the maximum waiting time `timeout` has been reached. If so, exits with an error message.
   - Sleeps for `interval` seconds before checking again if the workflow has been completed.
3. When the workflow run is completed, sets the `conclusion` output to the conclusion of the workflow run.

## Usage

To use this action, add it to your workflow file with the appropriate inputs. Example:

```yaml
- name: Wait on Workflow
  uses: lucasssvaz/wait-on-workflow@v1
  with:
    workflow: workflow.yml
    max-wait: 3
    interval: 5
    timeout: 60
    sha: ${{ github.event.pull_request.head.sha || github.sha }}
```

In case, you already have a workflow run ID, you can pass it this way:

```yaml
- name: Wait on Workflow
  uses: lucasssvaz/wait-on-workflow@v1
  with:
    workflow: 123123123
    max-wait: 3
    interval: 5
    timeout: 60
```

To access the outputs of this action, you can use the `id` specified in the action step:

```yaml
- name: Wait on Workflow
  uses: lucasssvaz/wait-on-workflow@v1
  id: wait-on-workflow
  with:
    workflow: workflow.yml
    sha: ${{ github.event.pull_request.head.sha || github.sha }}

- name: Get the workflow run ID
  run: |
    echo "Workflow run ID: ${{ steps.wait-on-workflow.outputs.run-id }}"
    echo "Workflow conclusion: ${{ steps.wait-on-workflow.outputs.conclusion }}"
```

## Notes

- The maximum wait time is specified in minutes. If the workflow has not been triggered or completed after the specified maximum wait time, the action will exit with an error. You can increase this value if you expect the workflow to take longer to start or complete. Keep in mind that the GitHub Actions runner has a default timeout of 6 hours for a job, so ensure your wait time falls within this limit.
