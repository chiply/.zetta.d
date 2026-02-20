# sourcefile: ${sourcefile}
import os

cmd = {
    "Github Actions": "cd ${projectile-project-name} && act --container-architecture linux/amd64 -W ./.github/workflows/${workflow_file} --secret-file ${secret_file_path} ${event_path} ${action}",
    "docker-compose": "echo hi",
}["${type}"]

os.system(cmd)


