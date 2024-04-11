from grpclib.server import Server
from deploy.server import DeploymentService
import asyncio


async def main():
    server = Server([DeploymentService()])
    await server.start("127.0.0.1", 50051)
    print("server started on localhost:50051")
    await server.wait_closed()

if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())