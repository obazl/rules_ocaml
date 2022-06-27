CCRED="\033[0;31m"
CCMAG="\033[0;35m"
CCRESET="\033[0;0m"

def debug_report_progress(repo_ctx, msg):
    if repo_ctx.attr.debug:
        print(msg)
        repo_ctx.report_progress(msg)
        for i in range(25000000):
            x = 1
