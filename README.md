# CloudflareSpeedTest + DNSPod规则 自动测速更新脚本

一个基于 Bash 的一键式工具：  
- 调用 [CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) 自动测速  
- 选出最快 IP 后，通过 DNSPod API 自动更新指定域名的 A 记录  

## 准备

1. 在DNSpod生成一个 A 记录，例如 test.yourdomain.com ，指向任意IP即可(因为我们马上就会更改这个ip）。
2. 前往 https://console.cloud.tencent.com/cam/capi 获取密钥id和key.

---

## 开始

下载脚本
```bash
 cd home
 curl -fsSL -o bestCFDNSpodip.sh https://raw.githubusercontent.com/Buriburizaem0n/bestCloudflareip_as_DNS/main/bestCFDNSpodip.sh
```
配置参数并尝试运行
### 赋予执行权限
```
 sudo chmod +x bestCFDNSpodip.sh
```
### 首次运行+填写参数
```
 sudo bash bestCFDNSpodip.sh --config
```
按照提示填写完所有参数，如果报错请检查是否手动创建了A记录、每一步是否输错。
如果一切正常，log输出：
```
新的IP地址: xx.xx.xx.xx
```
则说明运行完成，可以将其配置到crontab等自动工具中。本工具提供了一键配置，配置后将每十五分钟运行一次:
### 自动运行
```
 sudo bash bestCFDNSpodip.sh --auto
```
### 注意
不要删除脚本，除非你想停止脚本更新DNS记录，因为系统会循环运行该脚本，有问题欢迎提Issue.

## 致谢
特别感谢以下项目与服务，为本脚本的开发与运行提供了重要支持：
[Cloudflare](cloudflare.com):感谢赛博大善人提供的众多ip入口，Saas，CDN等等支持。

[XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest)：感谢 XIU2 开源并维护高效、精准的 CloudflareSpeedTest 工具，使本脚本能够一键测速并选出最优节点。

[ChatGPT](chatgpt.com)：感谢 ChatGPT 不辞辛劳的工作。

[腾讯云 DNSPod API](dnspod.cn)：感谢 DNSPod API 的稳定解析与丰富功能，让本脚本能够自动更新域名记录，保持服务高可用。

## 声明
本脚本仅作学习使用，请勿用于商业用途。
