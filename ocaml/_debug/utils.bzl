CCRED="\033[0;31m"
CCGRN="\033[0;32m"
CCORNG="\033[0;33m"
CCBLU="\033[0;34m"
CCMAG="\033[0;35m"
CCCYAN="\033[0;36m"
CCGRY="\033[0;37m"
CCRESET="\033[0;0m"

def debug_report_progress(repo_ctx, msg):
    if repo_ctx.attr.debug:
        print(msg)
        repo_ctx.report_progress(msg)
        for i in range(25000000):
            x = 1
