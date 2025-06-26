FROM node:16 as build     # 使用Node.js 16作为构建环境

WORKDIR /app              # 设置工作目录

COPY package*.json ./     # 复制package.json文件

# 添加npm镜像源配置
RUN npm config set registry https://registry.npmmirror.com && \
    npm install

COPY . .                  # 复制项目所有文件
ARG NODE_ENV=production   # 设置构建环境为生产环境
RUN npm run build         # 执行Vue项目构建命令，生成dist目录

FROM nginx:1.21           # 使用Nginx作为运行环境

# 添加时区设置
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY --from=build /app/dist /usr/share/nginx/html     # 复制构建产物到Nginx目录
COPY nginx.conf /etc/nginx/conf.d/default.conf        # 复制Nginx配置

EXPOSE 80                 # 暴露端口80

CMD ["nginx", "-g", "daemon off;"]      # 启动Nginx