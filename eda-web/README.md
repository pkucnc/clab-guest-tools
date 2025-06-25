# EDA 管理工具 Web 接口

这个目录包含 EDA 管理工具的 Web 接口配置和示例文件。

## 目录结构

```
/var/www/html/eda/
├── edaempyren2025summer.json
├── other-eda-configs.json
└── (其他 EDA 配置文件)
```

## 配置文件格式

每个 EDA 配置文件应该包含以下字段：

```json
{
  "network_segment": "192.168.132.0/22",
  "nfs_server": "192.168.132.10",
  "nfs_mounts": [
    {
      "source": "/opt/eda/tools",
      "target": "/opt/eda/tools",
      "options": "defaults,_netdev,soft,intr"
    },
    {
      "source": "/opt/eda/licenses",
      "target": "/opt/eda/licenses",
      "options": "defaults,_netdev,soft,intr"
    }
  ]
}
```

## 字段说明

- `network_segment`: 要求的网络段 (CIDR 格式)
- `nfs_server`: NFS 服务器 IP 地址
- `nfs_mounts`: NFS 挂载配置数组
  - `source`: NFS 服务器上的源路径
  - `target`: 本地挂载目标路径
  - `options`: NFS 挂载选项

## 使用方法

1. 将配置文件放置在 `/var/www/html/eda/` 目录下
2. 配置 nginx 以支持文件访问但禁止目录列表
3. 客户端使用 `clabcli eda <eda_name>` 命令访问配置
