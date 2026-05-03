<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\Device;

class DeviceController extends Controller {
    public function index() { return response()->json(['data' => Device::all()]); }
    public function store(Request $request) { return response()->json(['data' => Device::create($request->all())], 201); }
    public function update(Request $request, $id) { $model = Device::findOrFail($id); $model->update($request->all()); return response()->json(['data' => $model]); }
    public function destroy($id) { Device::destroy($id); return response()->json(['message' => 'Deleted']); }
}
