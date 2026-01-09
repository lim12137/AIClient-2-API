# 多阶段构建：构建阶段
FROM node:20-alpine AS builder
 
# 设置工作目录
WORKDIR /app
 
# 仅复制依赖文件，利用 Docker 层缓存
COPY package*.json ./
 
# 安装所有依赖（包括 devDependencies，如果需要构建步骤）
# 使用 npm ci 替代 npm install，更快更可靠
RUN npm ci --only=production && \
    npm cache clean --force
 
# 多阶段构建：运行阶段
FROM node:20-alpine
 
# 设置标签
LABEL maintainer="AIClient2API Team" \
      description="Docker image for AIClient2API server" \
      version="1.0"
 
# 安装运行时必需的系统工具
# 合并 RUN 命令减少层数，添加清理步骤
RUN apk add --no-cache \
    tar \
    git \
    dumb-init && \
    rm -rf /var/cache/apk/*
 
# 创建非 root 用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
 
# 设置工作目录
WORKDIR /app
 
# 从构建阶段复制依赖
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
 
# 复制应用代码
COPY --chown=nodejs:nodejs package*.json ./
COPY --chown=nodejs:nodejs src ./src
COPY --chown=nodejs:nodejs static ./static
COPY --chown=nodejs:nodejs healthcheck.js ./
COPY --chown=nodejs:nodejs VERSION ./
 
# 创建必要的目录并设置权限
RUN mkdir -p /app/logs /app/configs && \
    chown -R nodejs:nodejs /app
 
# 切换到非 root 用户
USER nodejs
 
# 暴露端口
EXPOSE 3000 8085 8086 19876-19880
 
# 添加健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node healthcheck.js || exit 1
 
# 使用 dumb-init 作为 PID 1，正确处理信号
ENTRYPOINT ["dumb-init", "--"]
 
# 启动命令
CMD ["node", "src/master.js"]
