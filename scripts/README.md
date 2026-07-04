# Scripts

Solo infra AWS (maintainers). El puente Arc One **no** vive acá — ver [arc-one-manifest-tools](https://github.com/arc-one-assurance/arc-one-manifest-tools).

| Script | Uso |
|--------|-----|
| `aws/bootstrap.sh` | Crear VPC, ECS cluster, ALB, roles (una vez) |
| `aws/deploy.sh` | Build + deploy imagen a ECS Fargate |

Registro del manifest: GitHub Actions (`Manifest PR Preview` / `Register with Arc One`).
