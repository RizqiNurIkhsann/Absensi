<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\Site;

class SiteController extends Controller {
    public function index() { return response()->json(['data' => Site::all()]); }
    public function store(Request $request) {
        $data = $request->all();
        if (empty($data['id'])) {
            $data['id'] = \Illuminate\Support\Str::uuid()->toString();
        }
        return response()->json(['data' => Site::create($data)], 201);
    }
    public function update(Request $request, $id) { $model = Site::findOrFail($id); $model->update($request->all()); return response()->json(['data' => $model]); }
    public function destroy($id) { Site::destroy($id); return response()->json(['message' => 'Deleted']); }
}
