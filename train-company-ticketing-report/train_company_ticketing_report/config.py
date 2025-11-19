from __future__ import annotations

import os
from dataclasses import dataclass
from dotenv import load_dotenv

load_dotenv()


@dataclass
class DatabaseSettings:
    host: str
    port: int
    name: str
    user: str
    password: str

    @classmethod
    def from_env(cls) -> "DatabaseSettings":
        # Prefer an explicit DB_HOST. If not provided, detect whether we're
        # running inside Kubernetes (presence of KUBERNETES_SERVICE_HOST or KUBERNETES_PORT)
        # and default to the cluster service name `postgres-svc`. Otherwise default
        # to localhost for local development.
        explicit_host = os.getenv("DB_HOST")
        if explicit_host:
            host = explicit_host
        elif os.getenv("KUBERNETES_SERVICE_HOST") or os.getenv("KUBERNETES_PORT"):
            host = "postgres-svc"
        else:
            host = "localhost"

        return cls(
            host=host,
            port=int(os.getenv("DB_PORT", "5432")),
            name=os.getenv("DB_NAME", "traindb"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", "mysecretpassword"),
        )

    def connection_kwargs(self) -> dict[str, str | int]:
        return {
            "host": self.host,
            "port": self.port,
            "dbname": self.name,
            "user": self.user,
            "password": self.password,
        }
