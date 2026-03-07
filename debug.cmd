@REM bun run --inspect-brk=9230 --cwd packages/opencode --conditions=browser src/index.ts run -m aliyun/glm-4.7 "请找出本项目有哪些命令注入安全风险。"

@REM bun run --inspect-brk=9230 --cwd packages/opencode --conditions=browser src/index.ts run -m aliyun/glm-4.7 "请找出本项目有哪些命令注入安全风险。"
bun run --inspect-brk=9230 --cwd packages/opencode --conditions=browser src/index.ts run -m aliyun/glm-4.7 -M e:\oss\opencode\hello.txt --dir E:\ai4sec\round3\SimplestWeb --agent secinsight
@REM bun run dev run -m aliyun/glm-4.7 "请找出本项目有哪些命令注入安全风险。"

@REM bun run dev run -m aliyun/glm-4.7 -M e:\oss\opencode\hello.txt --dir E:\ai4sec\round3\SimplestWeb --agent secinsight
