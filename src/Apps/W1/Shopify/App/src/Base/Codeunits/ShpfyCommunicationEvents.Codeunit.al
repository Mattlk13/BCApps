// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Codeunit Shpfy Communication Events (ID 30200).
/// </summary>
codeunit 30200 "Shpfy Communication Events"
{
    Access = Internal;

    [InternalEvent(false)]
    internal procedure OnClientSend(HttpRequestMessage: HttpRequestMessage; var HttpResponseMessage: HttpResponseMessage)
    begin
    end;

    [InternalEvent(false)]
    internal procedure OnGetAccessToken(var AccessToken: Text)
    begin
    end;

    [InternalEvent(false)]
    internal procedure OnGetContent(HttpResponseMessage: HttpResponseMessage; var Response: Text)
    begin
    end;

    [InternalEvent(false)]
    internal procedure OnClientPost(var Url: Text; var Content: HttpContent; var Response: HttpResponseMessage)
    begin
    end;

    [InternalEvent(false)]
    internal procedure OnClientGet(var Url: Text; var Response: HttpResponseMessage)
    begin
    end;
}
