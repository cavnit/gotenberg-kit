import Vapor

extension Application {
    public struct Gotenberg {
        let application: Application

        struct ConfigurationKey: StorageKey {
            typealias Value = GotenbergConfiguration
        }

        public var configuration: GotenbergConfiguration {
            get {
                guard let config: GotenbergConfiguration = application.storage[ConfigurationKey.self] else {
                    fatalError("GotenbergKit not configured. Use app.gotenberg.configuration = ...")
                }
                return config
            }
            nonmutating set {
                application.storage[ConfigurationKey.self] = newValue
            }
        }

        public var client: GotenbergClient {
            .init(
                client: application.client,
                logger: application.logger,
                configuration: configuration
            )
        }
    }

    public var gotenberg: Gotenberg {
        .init(application: self)
    }
}

extension Request {
    public struct Gotenberg {
        let request: Request

        public var client: GotenbergClient {
            let config: GotenbergConfiguration = request.application.gotenberg.configuration
            return .init(
                client: request.client,
                logger: request.logger,
                configuration: config
            )
        }
    }

    public var gotenberg: Gotenberg {
        .init(request: self)
    }
}
