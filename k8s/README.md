# K8s運用メモ (tileserver)

前提: このリポジトリ直下で実行する。

## 起動（デプロイ）
```bash
kubectl apply -f k8s/tileserver.yaml
```

## 停止（削除）
```bash
kubectl delete -f k8s/tileserver.yaml
```

## 再起動（ローリング）
```bash
kubectl rollout restart deployment/tileserver
```

## 状態確認
```bash
# Deploymentの状態
kubectl rollout status deployment/tileserver

# Pod一覧
kubectl get pods -l app=tileserver -o wide

# Service確認
kubectl get svc tileserver
```

## ログ確認
```bash
# 直近Podのログ
kubectl logs -l app=tileserver --tail=200
```

## 詳細確認（トラブル時）
```bash
kubectl describe deployment/tileserver
kubectl describe pod -l app=tileserver
```

## ローカル疎通確認
```bash
curl -I http://127.0.0.1:8000
```
