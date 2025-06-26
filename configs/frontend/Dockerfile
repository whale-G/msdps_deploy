# 第一阶段：构建阶段

# 使用Node.js 16作为构建环境
FROM node:16 as build     

# 设置工作目录，所有后续的命令都将在这个目录下执行
WORKDIR /app

# 复制package.json和package-lock.json到工作目录
COPY msdps_vue/package*.json .     
# ↑ 这样做的好处是利用Docker的缓存机制，如果依赖没有变化，就不会重新安装

# 添加npm镜像源配置并安装项目依赖
RUN npm config set registry https://registry.npmmirror.com && \
    npm install

# 复制所有源代码到工作目录
COPY msdps_vue/ .
# ↑ 这一步放在npm install后面是为了利用Docker的缓存层，避免源码改变导致重新安装依赖

# 设置Node环境变量为生产环境
ARG NODE_ENV=production   
# 执行构建命令，生成生产环境的静态文件
RUN npm run build
# ↑ 这个命令会执行package.json中定义的build脚本，通常会生成dist目录

# 第二阶段：运行阶段

# 使用Nginx作为运行环境
FROM nginx:1.21           

# 添加时区设置，确保容器内时间与中国时区一致
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 复制构建产物到Nginx目录
COPY --from=build /app/dist /usr/share/nginx/html   
# 复制Nginx配置  
COPY nginx.conf /etc/nginx/conf.d/default.conf        

# 暴露端口80
EXPOSE 80                 
# ↑ 这是文档性的，实际端口映射在docker-compose.yml中定义

# 启动Nginx
CMD ["nginx", "-g", "daemon off;"]
# ↑ 以前台方式运行nginx，这是Docker容器的最佳实践