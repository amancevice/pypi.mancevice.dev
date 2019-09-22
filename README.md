# pypi.mancevice.dev

Experiment in hosting a serverless PyPI server.

## Example Usage

```bash
pip install redpanda \
    --index-url https://pypi.mancevice.dev/simple/ \
    --trusted-host pypi.mancevice.dev \
    --extra-index-url https://pypi.org/simple/ \
    --trusted-host pypi.org
```
